import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/schema.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/shop.dart';

/// The phone's one shop. There is no sign-in any more (phone-only design §2):
/// the shop row on this phone IS the account, created once at onboarding.
class ShopRepository {
  ShopRepository(this._db);

  final AppDatabase _db;

  /// The shop on this phone, or `null` before onboarding created one.
  Future<Result<Shop?>> fetchMyShop() async {
    try {
      final rows = await _db.db.query('shops', orderBy: 'created_at', limit: 1);
      return Result.success(
        rows.isEmpty ? null : Shop.fromMap(decodeRow(rows.first)),
      );
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Creates the shop and its starter categories (0003's seed trigger) in one
  /// transaction.
  Future<Result<Shop>> createShop({
    required String name,
    String? address,
    String? phone,
    String currency = 'BDT',
  }) async {
    try {
      final id = newId();
      final now = nowMicros();
      await _db.db.transaction((txn) async {
        await txn.insert('shops', {
          'id': id,
          'name': name,
          'address': (address == null || address.isEmpty) ? null : address,
          'phone': (phone == null || phone.isEmpty) ? null : phone,
          'currency': currency,
          'created_at': now,
          'updated_at': now,
        });
        for (final c in defaultCategoryNames) {
          await txn.insert('categories', {
            'id': newId(),
            'shop_id': id,
            'name': c,
            'name_normalized': c.toLowerCase(),
            'created_at': now,
          });
        }
      });
      _db.notify({'shops', 'categories'});
      final shop = await fetchMyShop();
      return Result.success(shop.valueOrNull!);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Edits the shop's name, address, phone or currency.
  Future<Result<void>> updateShop(Shop shop) async {
    try {
      await _db.db.update(
        'shops',
        {
          'name': shop.name,
          'address': shop.address,
          'phone': shop.phone,
          'currency': shop.currency,
          'updated_at': nowMicros(),
        },
        where: 'id = ?',
        whereArgs: [shop.id],
      );
      _db.notify({'shops'});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  Failure _map(Object e) =>
      const DatabaseFailure('Could not save the shop. Please try again.');
}

final shopRepositoryProvider = Provider<ShopRepository>(
  (ref) => ShopRepository(ref.watch(appDatabaseProvider)),
);

/// The phone's shop (or null before onboarding). Re-reads itself when the
/// `shops` table changes (shop created, edited, or a backup restored).
final myShopProvider = FutureProvider<Shop?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  var seenFirst = false;
  // watch() emits once straight away; only later emissions are changes.
  final sub = db.watch({'shops'}, () async => null).listen((_) {
    if (seenFirst) ref.invalidateSelf();
    seenFirst = true;
  });
  ref.onDispose(sub.cancel);
  final result = await ref.watch(shopRepositoryProvider).fetchMyShop();
  return result.when(success: (shop) => shop, failure: (f) => throw f);
});
