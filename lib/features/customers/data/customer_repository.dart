import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

import '../../../core/db/app_database.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/customer.dart';
import '../domain/customer_balance.dart';
import '../domain/ledger_entry.dart';
import '../domain/receivables_summary.dart';

/// Customer credit ("khata") on the phone. A balance is always the SUM of the
/// append-only ledger (credit sales minus payments) and is never stored, so it
/// cannot drift (0008).
class CustomerRepository {
  CustomerRepository(this._db);

  final AppDatabase _db;

  static const _customers = 'customers';
  static const _ledger = 'customer_ledger';

  /// `get_customer_balances`: every customer with live balance and last
  /// activity, biggest debt first.
  Future<Result<List<CustomerBalance>>> customerBalances(String shopId) async {
    try {
      final rows = await _db.db.rawQuery(
        '''
        SELECT c.id, c.name, c.phone, c.note,
          COALESCE(SUM(CASE WHEN l.entry_type = 'credit_sale'
                            THEN l.amount_cents ELSE -l.amount_cents END), 0)
            AS balance_cents,
          MAX(l.created_at) AS last_activity_at
        FROM customers c
        LEFT JOIN customer_ledger l ON l.customer_id = c.id
        WHERE c.shop_id = ?
        GROUP BY c.id
        ORDER BY balance_cents DESC, c.name COLLATE NOCASE ASC''',
        [shopId],
      );
      return Result.success([
        for (final r in rows) CustomerBalance.fromMap(decodeRow(r)),
      ]);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  /// `get_receivables_summary`: total owed and how many customers owe.
  Future<Result<ReceivablesSummary>> receivablesSummary(String shopId) async {
    try {
      final rows = await _db.db.rawQuery(
        '''
        SELECT COALESCE(SUM(b), 0) AS total_owed_cents, COUNT(*) AS debtor_count
        FROM (
          SELECT SUM(CASE WHEN entry_type = 'credit_sale'
                          THEN amount_cents ELSE -amount_cents END) AS b
          FROM customer_ledger WHERE shop_id = ?
          GROUP BY customer_id
        ) WHERE b > 0''',
        [shopId],
      );
      return Result.success(ReceivablesSummary.fromMap(decodeRow(rows.first)));
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  Future<Result<Customer>> createCustomer({
    required String shopId,
    required String name,
    required String phone,
    String? note,
  }) async {
    try {
      final id = newId();
      final now = nowMicros();
      await _db.db.insert(_customers, {
        'id': id,
        'shop_id': shopId,
        'name': name,
        'phone': phone,
        'note': (note == null || note.isEmpty) ? null : note,
        'created_at': now,
        'updated_at': now,
      });
      _db.notify({_customers});
      return Result.success(await _customer(_db.db, id));
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  Future<Result<Customer>> updateCustomer({
    required String id,
    required String name,
    required String phone,
    String? note,
  }) async {
    try {
      await _db.db.update(
        _customers,
        {
          'name': name,
          'phone': phone,
          'note': (note == null || note.isEmpty) ? null : note,
          'updated_at': nowMicros(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      _db.notify({_customers});
      return Result.success(await _customer(_db.db, id));
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  /// `delete_customer`: only a settled customer (balance 0) can go; their
  /// ledger goes with them.
  Future<Result<void>> deleteCustomer({
    required String shopId,
    required String id,
  }) async {
    try {
      await _db.db.transaction((txn) async {
        if (await _balance(txn, shopId, id) != 0) {
          throw const LocalDbException(
            'Cannot delete a customer who still owes money',
          );
        }
        await txn.delete(
          _customers,
          where: 'id = ? AND shop_id = ?',
          whereArgs: [id, shopId],
        );
      });
      _db.notify({_customers, _ledger});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  Future<Result<List<LedgerEntry>>> ledgerFor(String customerId) async {
    try {
      final rows = await _db.db.query(
        _ledger,
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'created_at DESC',
      );
      return Result.success([
        for (final r in rows) LedgerEntry.fromJson(decodeRow(r)),
      ]);
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  /// `record_payment` (0020). [paymentId] is minted by the phone and re-sent
  /// on a retry, so a second tap cannot take the payment off twice. The
  /// amount is rounded to cents BEFORE the checks; overpaying is refused.
  Future<Result<LedgerEntry>> recordPayment({
    required String shopId,
    required String customerId,
    required double amount,
    required String paymentId,
    String? note,
  }) async {
    try {
      final row = await _db.db.transaction((txn) async {
        final done = await txn.query(
          _ledger,
          where: 'id = ? AND shop_id = ?',
          whereArgs: [paymentId, shopId],
        );
        if (done.isNotEmpty) return done.first;

        final cents = toCents(amount);
        if (cents <= 0) {
          throw const LocalDbException('Payment must be greater than zero');
        }
        final c = await txn.query(
          _customers,
          where: 'id = ? AND shop_id = ?',
          whereArgs: [customerId, shopId],
        );
        if (c.isEmpty) throw const LocalDbException('Customer not found');

        final owes = await _balance(txn, shopId, customerId);
        if (cents > owes) {
          throw LocalDbException(
            'Payment exceeds balance: owes ${(owes / 100).toStringAsFixed(2)}',
          );
        }
        await txn.insert(_ledger, {
          'id': paymentId,
          'shop_id': shopId,
          'customer_id': customerId,
          'entry_type': 'payment',
          'amount_cents': cents,
          'note': (note == null || note.isEmpty) ? null : note,
          'created_at': nowMicros(),
        });
        return (await txn.query(
          _ledger,
          where: 'id = ?',
          whereArgs: [paymentId],
        )).first;
      });
      _db.notify({_ledger});
      return Result.success(LedgerEntry.fromJson(decodeRow(row)));
    } catch (e) {
      return Result.failure(mapError(e));
    }
  }

  Future<int> _balance(
    DatabaseExecutor ex,
    String shopId,
    String customerId,
  ) async {
    final rows = await ex.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN entry_type = 'credit_sale'
                               THEN amount_cents ELSE -amount_cents END), 0) AS b
      FROM customer_ledger WHERE customer_id = ? AND shop_id = ?''',
      [customerId, shopId],
    );
    return rows.first['b']! as int;
  }

  Future<Customer> _customer(DatabaseExecutor ex, String id) async {
    final rows = await ex.query(_customers, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw const LocalDbException('Customer not found');
    return Customer.fromJson(decodeRow(rows.first));
  }

  /// Writer errors carry user-meaningful text ("Payment exceeds balance: owes
  /// 150"), surfaced directly as before.
  @visibleForTesting
  Failure mapError(Object e) {
    if (e is LocalDbException) {
      final (:code, :detail) = classifyServerMessage(e.message);
      return DatabaseFailure(e.message, code: code, detail: detail);
    }
    return const DatabaseFailure(
      'Could not complete the request. Please try again.',
    );
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(appDatabaseProvider));
});
