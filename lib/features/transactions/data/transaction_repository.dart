import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

import '../../../core/db/app_database.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../expiry/data/batch_repository.dart';
import '../../expiry/domain/expiry_dates.dart';
import '../domain/transaction.dart';
import 'day_range.dart';
import 'sale_cart_writer.dart';

/// Every sale column plus the expiry date of the delivery it came from.
const _saleSelect = '''
  SELECT t.*, b.expiry_date AS batch_expiry_date
  FROM transactions t
  LEFT JOIN product_batches b ON b.id = t.batch_id''';

/// A stored transaction row as [Transaction.fromJson] reads it (the delivery's
/// expiry nested under `batch`, as the old PostgREST embed returned it).
Transaction transactionFromRow(Map<String, Object?> row) {
  final json = decodeRow(row);
  final expiry = json.remove('batch_expiry_date');
  if (expiry != null) json['batch'] = {'expiry_date': expiry};
  return Transaction.fromJson(json);
}

/// Records stock movements atomically in the phone's database. Each writer is
/// a port of the Postgres function named in its doc and runs in ONE SQLite
/// transaction: stock, sale rows, discount split and khata debt all commit
/// together or not at all (design §3).
class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;

  /// Restock (`record_restock`, 0011). [restockId] is minted by the caller and
  /// re-sent on a retry: a given id is recorded once, a repeat returns the
  /// existing row. With [expiryDate] the delivery is recorded in the same
  /// transaction; [receivedOn] is the phone's local date.
  Future<Result<Transaction>> recordRestock({
    required String shopId,
    required String productId,
    required double quantity,
    required String restockId,
    String source = 'manual',
    DateTime? expiryDate,
    DateTime? receivedOn,
  }) async {
    try {
      final row = await _db.db.transaction((txn) async {
        final existing = await _byId(txn, shopId, restockId);
        if (existing != null) return existing;

        final qty = toMilli(quantity);
        if (qty <= 0) {
          throw const LocalDbException('Quantity must be greater than zero');
        }
        final product = await _product(txn, shopId, productId);
        final now = nowMicros();
        await txn.rawUpdate(
          'UPDATE products SET quantity_milli = quantity_milli + ?, '
          'updated_at = ? WHERE id = ?',
          [qty, now, productId],
        );
        await txn.insert('transactions', {
          'id': restockId,
          'shop_id': shopId,
          'product_id': productId,
          'type': 'restock',
          'quantity_milli': qty,
          'buying_price_cents': product['buying_price_cents'],
          'selling_price_cents': product['selling_price_cents'],
          'source': source,
          'created_at': now,
        });
        if (expiryDate != null) {
          await insertDeliveryMerged(
            txn,
            shopId: shopId,
            productId: productId,
            quantityMilli: qty,
            buyingPriceCents: product['buying_price_cents']! as int,
            receivedOn: ymd(receivedOn ?? DateTime.now()),
            expiryDate: ymd(expiryDate),
          );
        }
        return (await _byId(txn, shopId, restockId))!;
      });
      _db.notify({'products', 'transactions', 'product_batches'});
      return Result.success(row);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Multi-item checkout (`record_sale_cart`, 0018). Every line commits, or
  /// none (e.g. insufficient stock). The rows share one `sale_group_id`.
  ///
  /// [saleGroupId] is minted by the caller: a repeat of the same id returns
  /// the rows already recorded instead of selling twice.
  ///
  /// [items] are `{product_id, quantity, batch_id?}`. [digital] marks a
  /// paid-now sale as digital; a sale with [customerId] is credit.
  Future<Result<List<Transaction>>> recordSaleCart({
    required String shopId,
    required List<Map<String, dynamic>> items,
    required String saleGroupId,
    String source = 'manual',
    String? customerId,
    double discount = 0,
    bool digital = false,
  }) async {
    try {
      final rows = await _db.db.transaction((txn) async {
        await writeSaleCart(
          txn,
          shopId: shopId,
          items: items,
          group: saleGroupId,
          source: source,
          customerId: customerId,
          discountCents: toCents(discount),
          method: digital ? 'digital' : 'cash',
        );
        return _group(txn, shopId, saleGroupId);
      });
      _db.notify({
        'products',
        'transactions',
        'product_batches',
        'customer_ledger',
      });
      return Result.success(rows);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  Future<List<Transaction>> _group(
    DatabaseExecutor txn,
    String shopId,
    String group,
  ) async {
    final rows = await txn.rawQuery(
      '$_saleSelect WHERE t.shop_id = ? AND t.sale_group_id = ? '
      'ORDER BY t.rowid',
      [shopId, group],
    );
    return [for (final r in rows) transactionFromRow(r)];
  }

  Future<Transaction?> _byId(
    DatabaseExecutor txn,
    String shopId,
    String id,
  ) async {
    final rows = await txn.rawQuery(
      '$_saleSelect WHERE t.id = ? AND t.shop_id = ?',
      [id, shopId],
    );
    return rows.isEmpty ? null : transactionFromRow(rows.first);
  }

  Future<Map<String, Object?>> _product(
    DatabaseExecutor txn,
    String shopId,
    String productId,
  ) async {
    final rows = await txn.query(
      'products',
      where: 'id = ? AND shop_id = ?',
      whereArgs: [productId, shopId],
      limit: 1,
    );
    if (rows.isEmpty) throw const LocalDbException('Product not found');
    return rows.first;
  }

  /// Recent SALE transactions, newest first; [since] bounds the window.
  Future<Result<List<Transaction>>> recentSales({
    required String shopId,
    int limit = 100,
    DateTime? since,
  }) async {
    try {
      final rows = await _db.db.rawQuery(
        '$_saleSelect WHERE t.shop_id = ? AND t.type = \'sale\''
        '${since != null ? ' AND t.created_at >= ?' : ''} '
        'ORDER BY t.created_at DESC LIMIT ?',
        [
          shopId,
          if (since != null) since.toUtc().microsecondsSinceEpoch,
          limit,
        ],
      );
      return Result.success([for (final r in rows) transactionFromRow(r)]);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// All SALE transactions on [day] (local calendar day), newest first.
  Future<Result<List<Transaction>>> salesForDay({
    required String shopId,
    required DateTime day,
  }) async {
    try {
      final range = dayRangeUtc(day);
      final rows = await _db.db.rawQuery(
        '$_saleSelect WHERE t.shop_id = ? AND t.type = \'sale\' '
        'AND t.created_at >= ? AND t.created_at < ? '
        'ORDER BY t.created_at DESC',
        [
          shopId,
          range.startUtc.microsecondsSinceEpoch,
          range.endUtc.microsecondsSinceEpoch,
        ],
      );
      return Result.success([for (final r in rows) transactionFromRow(r)]);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// The local calendar date of the shop's first sale, or null.
  Future<Result<DateTime?>> earliestSaleDate({required String shopId}) async {
    try {
      final rows = await _db.db.rawQuery(
        "SELECT MIN(created_at) AS first FROM transactions "
        "WHERE shop_id = ? AND type = 'sale'",
        [shopId],
      );
      final first = rows.first['first'] as int?;
      if (first == null) return const Result.success(null);
      final local = DateTime.fromMicrosecondsSinceEpoch(first, isUtc: true)
          .toLocal();
      return Result.success(DateTime(local.year, local.month, local.day));
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Writer errors carry the old Postgres wording, so the same classifier
  /// gives the UI a translatable [Failure.code].
  Failure _map(Object e) {
    if (e is LocalDbException) {
      final (:code, :detail) = classifyServerMessage(e.message);
      return DatabaseFailure(e.message, code: code, detail: detail);
    }
    return const DatabaseFailure(
      'Could not complete the transaction. Please try again.',
    );
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(appDatabaseProvider));
});
