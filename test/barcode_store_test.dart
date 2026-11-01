// A pack's barcode names its product exactly once the shop has confirmed one
// scan of it, whatever the label's script or lettering.
import 'dart:io';

import 'package:ai_shopkeeper/core/db/app_database.dart';
import 'package:ai_shopkeeper/core/db/schema.dart';
import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/auth/data/auth_repository.dart';
import 'package:ai_shopkeeper/features/inventory/data/product_repository.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/scan/data/barcode_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

T ok<T>(Result<T> r) => r.when(
  success: (v) => v,
  failure: (f) => throw StateError('expected success, got ${f.message}'),
);

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late ProductRepository products;
  late BarcodeStore codes;
  late String shopId;

  Future<String> product(String name) async => ok(
    await products.addProduct(Product(id: '', shopId: shopId, name: name)),
  ).id;

  setUp(() async {
    db = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
    shopId = ok(await ShopRepository(db).createShop(name: 'Test shop')).id;
    products = ProductRepository(db);
    codes = BarcodeStore(db);
  });

  tearDown(() => db.close());

  test('an unknown barcode names nothing', () async {
    await product('Pran Mango Juice');
    expect(await codes.productFor(['8941100500019']), isNull);
    expect(await codes.productFor(const []), isNull);
  });

  test('a learned barcode names its product', () async {
    final juice = await product('Pran Mango Juice');
    await codes.learn(juice, '8941100500019');
    expect(await codes.productFor(['123', '8941100500019']), juice);
  });

  test('a product can have several barcodes', () async {
    final oil = await product('Teer Soybean Oil');
    await codes.learn(oil, '8941193000017');
    await codes.learn(oil, '8941193000024');
    expect(await codes.productFor(['8941193000017']), oil);
    expect(await codes.productFor(['8941193000024']), oil);
  });

  test('re-teaching a barcode moves it to the corrected product', () async {
    final a = await product('Lux Soap 100g');
    final b = await product('Lux Soap 150g');
    await codes.learn(a, '8901030000001');
    await codes.learn(b, '8901030000001');
    expect(await codes.productFor(['8901030000001']), b);
  });

  test('an archived product is not matched by its barcode', () async {
    final id = await product('Old Biscuit');
    await codes.learn(id, '8940000000001');
    ok(await products.deleteProduct(id));
    expect(await codes.productFor(['8940000000001']), isNull);
  });

  test('a version 1 database gains the barcode table on upgrade', () async {
    final dir = await Directory.systemTemp.createTemp('easysell_db');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}v1.db';
    final f = databaseFactoryFfiNoIsolate;
    final v1 = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) async {
          for (final s in schemaStatements) {
            if (!s.contains('product_barcodes')) await d.execute(s);
          }
        },
      ),
    );
    await v1.close();

    final upgraded = await AppDatabase.open(path: path, factory: f);
    addTearDown(upgraded.close);
    expect(await upgraded.db.getVersion(), schemaVersion);
    final store = BarcodeStore(upgraded);
    final shop = ok(await ShopRepository(upgraded).createShop(name: 'Shop'));
    final id = ok(
      await ProductRepository(
        upgraded,
      ).addProduct(Product(id: '', shopId: shop.id, name: 'Juice')),
    ).id;
    await store.learn(id, '8941100500019');
    expect(await store.productFor(['8941100500019']), id);
  });
}
