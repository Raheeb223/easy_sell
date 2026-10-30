import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

import '../../../core/db/app_database.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../inventory/domain/product.dart';
import '../domain/expiry_dates.dart';
import '../domain/expiry_estimate.dart';
import '../domain/product_batch.dart';
import '../domain/removal_loss.dart';

/// Open deliveries and the products they belong to, read together.
typedef ExpirySnapshot = ({List<ProductBatch> batches, List<Product> products});

/// Adds a delivery, JOINING an open one of the same product with the same
/// received date, expiry date and buying price instead of inserting
/// (0016 `merge_same_delivery`). A delivery with a locked expired count is
/// never joined. Stock is the caller's job, exactly as for a new delivery.
Future<void> insertDeliveryMerged(
  DatabaseExecutor txn, {
  required String shopId,
  required String productId,
  required int quantityMilli,
  required int buyingPriceCents,
  required String receivedOn,
  required String expiryDate,
}) async {
  final same = await txn.rawQuery(
    'SELECT id FROM product_batches '
    'WHERE shop_id = ? AND product_id = ? AND closed_at IS NULL '
    'AND expired_qty_milli IS NULL AND expiry_date = ? AND received_on = ? '
    'AND buying_price_cents = ? ORDER BY created_at, id LIMIT 1',
    [shopId, productId, expiryDate, receivedOn, buyingPriceCents],
  );
  if (same.isNotEmpty) {
    await txn.rawUpdate(
      'UPDATE product_batches SET quantity_milli = quantity_milli + ? '
      'WHERE id = ?',
      [quantityMilli, same.first['id']],
    );
    return;
  }
  await txn.insert('product_batches', {
    'id': newId(),
    'shop_id': shopId,
    'product_id': productId,
    'quantity_milli': quantityMilli,
    'buying_price_cents': buyingPriceCents,
    'received_on': receivedOn,
    'expiry_date': expiryDate,
    'created_at': nowMicros(),
  });
}

/// Reads and writes `product_batches` (deliveries with an expiry date).
class BatchRepository {
  BatchRepository(this._db);

  final AppDatabase _db;
  static const _table = 'product_batches';
  static const _tables = {'products', 'transactions', _table};

  /// The shop's OPEN deliveries, live.
  Stream<List<ProductBatch>> watchOpenBatches(String shopId) => _db.watch(
    {_table},
    () async {
      final rows = await _db.db.query(
        _table,
        where: 'shop_id = ? AND closed_at IS NULL',
        whereArgs: [shopId],
      );
      return [for (final r in rows) ProductBatch.fromJson(decodeRow(r))];
    },
  );

  /// The shop's open deliveries WITH their (non-archived) products, read in
  /// one transaction so a sale cannot land between the two reads.
  Future<Result<ExpirySnapshot>> fetchExpirySnapshot(String shopId) async {
    try {
      final snap = await _db.db.transaction((txn) async {
        final batches = await txn.rawQuery(
          'SELECT b.* FROM product_batches b JOIN products p ON p.id = b.product_id '
          'WHERE b.shop_id = ? AND b.closed_at IS NULL AND p.is_archived = 0',
          [shopId],
        );
        final products = await txn.rawQuery(
          'SELECT * FROM products WHERE is_archived = 0 AND id IN '
          '(SELECT product_id FROM product_batches '
          ' WHERE shop_id = ? AND closed_at IS NULL)',
          [shopId],
        );
        return (
          batches: [
            for (final r in batches) ProductBatch.fromJson(decodeRow(r)),
          ],
          products: [for (final r in products) Product.fromJson(decodeRow(r))],
        );
      });
      return Result.success(snap);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Everything ever removed from [productId]'s stock, in units and money.
  Future<Result<RemovalLoss>> fetchRemovalLoss(String productId) async {
    try {
      final rows = await _db.db.rawQuery(
        "SELECT quantity_milli, buying_price_cents FROM transactions "
        "WHERE product_id = ? AND type = 'adjustment'",
        [productId],
      );
      return Result.success(
        RemovalLoss.fromRows([for (final r in rows) decodeRow(r)]),
      );
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Adds a delivery for stock already counted (no stock change), joining an
  /// identical open delivery when there is one.
  Future<Result<void>> addBatch({
    required String shopId,
    required String productId,
    required double quantity,
    required double buyingPrice,
    required DateTime receivedOn,
    required DateTime expiryDate,
  }) async {
    try {
      final qty = toMilli(quantity);
      if (qty <= 0) {
        throw const LocalDbException('Quantity must be greater than zero');
      }
      await _db.db.transaction(
        (txn) => insertDeliveryMerged(
          txn,
          shopId: shopId,
          productId: productId,
          quantityMilli: qty,
          buyingPriceCents: toCents(buyingPrice),
          receivedOn: ymd(receivedOn),
          expiryDate: ymd(expiryDate),
        ),
      );
      _db.notify({_table});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Edits an OPEN delivery. [clearLock] removes a locked expired count;
  /// [lockedQty] lowers a lock that stays.
  Future<Result<void>> updateBatch({
    required String batchId,
    required double quantity,
    required DateTime expiryDate,
    required bool clearLock,
    double? lockedQty,
  }) async {
    try {
      await _db.db.update(
        _table,
        {
          'quantity_milli': toMilli(quantity),
          'expiry_date': ymd(expiryDate),
          if (clearLock)
            'expired_qty_milli': null
          else if (lockedQty != null)
            'expired_qty_milli': toMilli(lockedQty),
        },
        where: 'id = ? AND closed_at IS NULL',
        whereArgs: [batchId],
      );
      _db.notify({_table});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  Future<Result<void>> closeBatch(String batchId, String reason) async {
    try {
      await _close(_db.db, batchId, reason);
      _db.notify({_table});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Stores reconcile writes. Each touches only a still-open row (and a lock
  /// only a still-unlocked one), so a repeat changes nothing.
  Future<Result<void>> applyReconcile(List<ReconcileWrite> writes) async {
    try {
      await _db.db.transaction((txn) async {
        for (final w in writes) {
          switch (w) {
            case LockExpired(:final batchId, :final quantity):
              await txn.update(
                _table,
                {'expired_qty_milli': toMilli(quantity)},
                where:
                    'id = ? AND closed_at IS NULL AND expired_qty_milli IS NULL',
                whereArgs: [batchId],
              );
            case CloseSoldOut(:final batchId):
              await _close(txn, batchId, BatchCloseReason.soldOut);
          }
        }
      });
      if (writes.isNotEmpty) _db.notify({_table});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// `remove_batch_stock` (0014): lowers stock by an expired delivery's
  /// locked count, or by [quantity] for one that has not expired, and records
  /// the loss as an `adjustment`. [close] false removes only part (the units
  /// count as picked from this delivery, which stays open). [removalId] makes
  /// a retry a no-op.
  Future<Result<void>> removeStock({
    required String shopId,
    required String batchId,
    double? quantity,
    bool close = true,
    String? removalId,
  }) async {
    final id = removalId ?? newId();
    try {
      await _db.db.transaction((txn) async {
        final done = await txn.rawQuery(
          'SELECT 1 FROM transactions WHERE id = ? AND shop_id = ?',
          [id, shopId],
        );
        if (done.isNotEmpty) return;

        final batches = await txn.query(
          _table,
          where: 'id = ? AND shop_id = ?',
          whereArgs: [batchId, shopId],
        );
        if (batches.isEmpty) throw const LocalDbException('Delivery not found');
        final b = batches.first;
        // Already closed: a second tap or a retry. Change nothing.
        if (b['closed_at'] != null) return;

        final products = await txn.query(
          'products',
          where: 'id = ? AND shop_id = ?',
          whereArgs: [b['product_id'], shopId],
        );
        if (products.isEmpty) throw const LocalDbException('Product not found');
        final p = products.first;

        var shut = close;
        int qty;
        final locked = b['expired_qty_milli'] as int?;
        if (locked != null) {
          qty = locked;
          shut = true;
        } else if (quantity == null) {
          throw const LocalDbException('Delivery is not expired');
        } else if (toMilli(quantity) <= 0) {
          throw const LocalDbException('Quantity must be greater than zero');
        } else {
          final left =
              (b['quantity_milli']! as int) - (b['picked_qty_milli']! as int);
          qty = _min(toMilli(quantity), left < 0 ? 0 : left);
        }
        // Stock may have been lowered below the delivery's count.
        qty = _min(qty, p['quantity_milli']! as int);

        final now = nowMicros();
        if (qty > 0) {
          await txn.rawUpdate(
            'UPDATE products SET quantity_milli = quantity_milli - ?, '
            'updated_at = ? WHERE id = ?',
            [qty, now, p['id']],
          );
          await txn.insert('transactions', {
            'id': id,
            'shop_id': shopId,
            'product_id': p['id'],
            'type': 'adjustment',
            'quantity_milli': qty,
            'buying_price_cents': b['buying_price_cents'],
            'selling_price_cents': p['selling_price_cents'],
            'source': 'manual',
            'batch_id': batchId,
            'created_at': now,
          });
        }
        if (shut) {
          await _close(txn, batchId, BatchCloseReason.removed);
        } else {
          await txn.rawUpdate(
            'UPDATE product_batches SET picked_qty_milli = picked_qty_milli + ? '
            'WHERE id = ?',
            [qty, batchId],
          );
        }
      });
      _db.notify(_tables);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// `remove_undated_stock` (0015): lowers stock that sits in no delivery by
  /// [quantity] (capped at stock), recording the loss. [removalId] makes a
  /// retry a no-op.
  Future<Result<void>> removeUndatedStock({
    required String shopId,
    required String productId,
    required double quantity,
    required String removalId,
  }) async {
    try {
      await _db.db.transaction((txn) async {
        final done = await txn.rawQuery(
          'SELECT 1 FROM transactions WHERE id = ? AND shop_id = ?',
          [removalId, shopId],
        );
        if (done.isNotEmpty) return;

        final want = toMilli(quantity);
        if (want <= 0) {
          throw const LocalDbException('Quantity must be greater than zero');
        }
        final products = await txn.query(
          'products',
          where: 'id = ? AND shop_id = ?',
          whereArgs: [productId, shopId],
        );
        if (products.isEmpty) throw const LocalDbException('Product not found');
        final p = products.first;
        final have = p['quantity_milli']! as int;
        final qty = _min(want, have);
        if (qty <= 0) {
          throw LocalDbException(
            'Insufficient stock for ${p['name']}: have '
            '${(have / 1000).toStringAsFixed(3)}, need $quantity',
          );
        }
        final now = nowMicros();
        await txn.rawUpdate(
          'UPDATE products SET quantity_milli = quantity_milli - ?, '
          'updated_at = ? WHERE id = ?',
          [qty, now, productId],
        );
        await txn.insert('transactions', {
          'id': removalId,
          'shop_id': shopId,
          'product_id': productId,
          'type': 'adjustment',
          'quantity_milli': qty,
          'buying_price_cents': p['buying_price_cents'],
          'selling_price_cents': p['selling_price_cents'],
          'source': 'manual',
          'created_at': now,
        });
      });
      _db.notify(_tables);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Local date of the product's latest restock, or null if never restocked.
  Future<Result<DateTime?>> latestRestockDate(String productId) async {
    try {
      final rows = await _db.db.rawQuery(
        "SELECT MAX(created_at) AS last FROM transactions "
        "WHERE product_id = ? AND type = 'restock'",
        [productId],
      );
      final last = rows.first['last'] as int?;
      if (last == null) return const Result.success(null);
      return Result.success(
        dateOnly(
          DateTime.fromMicrosecondsSinceEpoch(last, isUtc: true).toLocal(),
        ),
      );
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  Future<void> _close(DatabaseExecutor ex, String batchId, String reason) =>
      ex.update(
        _table,
        {'closed_at': nowMicros(), 'closed_reason': reason},
        where: 'id = ? AND closed_at IS NULL',
        whereArgs: [batchId],
      );

  Failure _map(Object e) {
    if (e is LocalDbException) {
      final (:code, :detail) = classifyServerMessage(e.message);
      return DatabaseFailure(e.message, code: code, detail: detail);
    }
    return const DatabaseFailure('Could not save the delivery.');
  }
}

int _min(int a, int b) => a < b ? a : b;

final batchRepositoryProvider = Provider<BatchRepository>((ref) {
  return BatchRepository(ref.watch(appDatabaseProvider));
});
