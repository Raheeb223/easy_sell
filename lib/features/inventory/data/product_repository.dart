import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/product.dart';

/// CRUD + live access for `products` in the phone's database. Everything
/// returns a [Result] (except the live stream, whose errors flow through
/// `AsyncValue`).
class ProductRepository {
  ProductRepository(this._db);

  final AppDatabase _db;

  static const _table = 'products';

  /// Live, name-ordered list of a shop's *active* products. Re-reads after
  /// every write to `products` (sales, restocks and edits all notify).
  Stream<List<Product>> watchProducts(String shopId) => _db.watch(
    {_table},
    () => _list(shopId, archived: false),
  );

  Future<List<Product>> _list(String shopId, {required bool archived}) async {
    final rows = await _db.db.query(
      _table,
      where: 'shop_id = ? AND is_archived = ?',
      whereArgs: [shopId, archived ? 1 : 0],
      orderBy: 'name COLLATE NOCASE',
    );
    return [for (final r in rows) Product.fromJson(decodeRow(r))];
  }

  /// One product by id, archived or not.
  Future<Product?> findById(String id) async {
    final rows = await _db.db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Product.fromJson(decodeRow(rows.first));
  }

  Future<Result<Product>> addProduct(Product product) async {
    try {
      final id = newId();
      final now = nowMicros();
      await _db.db.insert(_table, {
        'id': id,
        ..._encode(product),
        'quantity_milli': toMilli(product.quantity),
        'created_at': now,
        'updated_at': now,
      });
      _db.notify({_table});
      return Result.success((await findById(id))!);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Saves the editable fields. Stock is never written here: it moves only
  /// through sales, restocks and removals (0015).
  Future<Result<Product>> updateProduct(Product product) async {
    try {
      await _db.db.update(
        _table,
        {..._encode(product), 'updated_at': nowMicros()},
        where: 'id = ?',
        whereArgs: [product.id],
      );
      _db.notify({_table});
      final saved = await findById(product.id);
      if (saved == null) {
        return const Result.failure(DatabaseFailure('Product not found'));
      }
      return Result.success(saved);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Soft-deletes a product by archiving it, so its sales history (frozen
  /// prices) stays intact. Reversible with [restoreProduct].
  Future<Result<void>> deleteProduct(String id) => _setArchived(id, true);

  /// Un-archives a product, returning it to the active inventory.
  Future<Result<void>> restoreProduct(String id) => _setArchived(id, false);

  Future<Result<void>> _setArchived(String id, bool archived) async {
    try {
      await _db.db.update(
        _table,
        {'is_archived': archived ? 1 : 0, 'updated_at': nowMicros()},
        where: 'id = ?',
        whereArgs: [id],
      );
      _db.notify({_table});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Name-ordered list of a shop's *archived* products (Settings → Archived).
  Future<List<Product>> fetchArchivedProducts(String shopId) =>
      _list(shopId, archived: true);

  /// The product photo paths are stored on the row; the vision model keeps its
  /// own fingerprints in `product_embeddings`.
  Future<Result<void>> setImages(String id, List<String> paths) async {
    try {
      await _db.db.update(
        _table,
        {'image_urls': encodeStringList(paths), 'updated_at': nowMicros()},
        where: 'id = ?',
        whereArgs: [id],
      );
      _db.notify({_table});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  Map<String, Object?> _encode(Product p) => {
    'shop_id': p.shopId,
    'name': p.name,
    'unit_type': p.unitType.name,
    'unit': p.unit.name,
    'brand': p.brand,
    'variant': p.variant,
    'category_id': p.categoryId,
    'buying_price_cents': toCents(p.buyingPrice),
    'selling_price_cents': toCents(p.sellingPrice),
    'reorder_threshold_milli': toMilli(p.reorderThreshold),
    'expiry_warn_days': p.expiryWarnDays,
    'image_urls': encodeStringList(p.imageUrls),
  };

  Failure _map(Object e) =>
      const DatabaseFailure('Could not complete the request. Please try again.');
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(appDatabaseProvider));
});
