// The phone database keeps every money rule the Postgres functions enforced
// (phone-only design §3). Each test mirrors one rule against a real SQLite
// database (in memory, through sqflite's FFI build).
import 'package:ai_shopkeeper/core/db/app_database.dart';
import 'package:ai_shopkeeper/core/db/backup.dart';
import 'package:ai_shopkeeper/core/db/photo_store.dart';
import 'package:ai_shopkeeper/core/error/failure.dart';
import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/analytics/data/analytics_repository.dart';
import 'package:ai_shopkeeper/features/analytics/domain/analytics.dart';
import 'package:ai_shopkeeper/features/auth/data/auth_repository.dart';
import 'package:ai_shopkeeper/features/customers/data/customer_repository.dart';
import 'package:ai_shopkeeper/features/expiry/data/batch_repository.dart';
import 'package:ai_shopkeeper/features/inventory/data/product_repository.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/transactions/data/sale_cart_writer.dart';
import 'package:ai_shopkeeper/features/transactions/data/transaction_repository.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

T ok<T>(Result<T> r) => r.when(
  success: (v) => v,
  failure: (f) => throw StateError('expected success, got ${f.message}'),
);

Failure bad<T>(Result<T> r) => r.when(
  success: (_) => throw StateError('expected failure'),
  failure: (f) => f,
);

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late String shopId;
  late ProductRepository products;
  late TransactionRepository txns;
  late CustomerRepository customers;
  late BatchRepository batches;

  Future<Product> product(
    String name, {
    double qty = 10,
    double buy = 30,
    double sell = 45,
    ProductUnit unit = ProductUnit.pcs,
  }) async => ok(
    await products.addProduct(
      Product(
        id: '',
        shopId: shopId,
        name: name,
        quantity: qty,
        buyingPrice: buy,
        sellingPrice: sell,
        unit: unit,
        unitType: unit == ProductUnit.pcs ? UnitType.piece : UnitType.weight,
      ),
    ),
  );

  Future<double> stock(String id) async =>
      (await products.findById(id))!.quantity;

  setUp(() async {
    db = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
    final shop = ok(await ShopRepository(db).createShop(name: 'Test shop'));
    shopId = shop.id;
    products = ProductRepository(db);
    txns = TransactionRepository(db);
    customers = CustomerRepository(db);
    batches = BatchRepository(db);
  });

  tearDown(() => db.close());

  test('new shop gets the starter categories', () async {
    final rows = await db.db.query('categories');
    expect(rows, hasLength(10));
  });

  group('record_sale_cart', () {
    test('sells every line atomically with frozen prices', () async {
      final pepsi = await product('Pepsi', qty: 10, sell: 45, buy: 30);
      final chips = await product('Chips', qty: 5, sell: 20, buy: 12);
      final rows = ok(
        await txns.recordSaleCart(
          shopId: shopId,
          saleGroupId: 'g1',
          items: [
            {'product_id': pepsi.id, 'quantity': 2},
            {'product_id': chips.id, 'quantity': 3},
          ],
        ),
      );
      expect(rows, hasLength(2));
      expect(await stock(pepsi.id), 8);
      expect(await stock(chips.id), 2);
      expect(rows.every((t) => t.paymentMethod == 'cash'), isTrue);

      // Changing the price later never rewrites history.
      ok(await products.updateProduct(pepsi.copyWith(sellingPrice: 99)));
      final history = ok(await txns.recentSales(shopId: shopId));
      final sold = history.firstWhere((t) => t.productId == pepsi.id);
      expect(sold.sellingPrice, 45);
      expect(sold.buyingPrice, 30);
    });

    test('a retry with the same sale id records nothing twice', () async {
      final pepsi = await product('Pepsi', qty: 10);
      for (var i = 0; i < 3; i++) {
        final rows = ok(
          await txns.recordSaleCart(
            shopId: shopId,
            saleGroupId: 'same-id',
            items: [
              {'product_id': pepsi.id, 'quantity': 4},
            ],
          ),
        );
        expect(rows, hasLength(1));
      }
      expect(await stock(pepsi.id), 6);
    });

    test('one short line rolls back the whole cart, coded for the UI', () async {
      final pepsi = await product('Pepsi', qty: 10);
      final chips = await product('Chips', qty: 1);
      final f = bad(
        await txns.recordSaleCart(
          shopId: shopId,
          saleGroupId: 'g2',
          items: [
            {'product_id': pepsi.id, 'quantity': 2},
            {'product_id': chips.id, 'quantity': 3},
          ],
        ),
      );
      expect(f.code, ServerErrorCodes.insufficientStock);
      expect(f.detail, 'Chips');
      expect(await stock(pepsi.id), 10);
      expect(await db.db.query('transactions'), isEmpty);
    });

    test('discount shares sum exactly to the discount (the 225.09 case)', () async {
      final a = await product('Loose A', qty: 10, sell: 45, unit: ProductUnit.kg);
      final b = await product('Loose B', qty: 10, sell: 45, unit: ProductUnit.kg);
      final rows = ok(
        await txns.recordSaleCart(
          shopId: shopId,
          saleGroupId: 'g3',
          discount: 225.08,
          items: [
            {'product_id': a.id, 'quantity': 2.501},
            {'product_id': b.id, 'quantity': 2.501},
          ],
        ),
      );
      final total = rows.fold<double>(0, (s, t) => s + t.discountAmount);
      expect((total * 100).round(), 22508);
      // 225.09 is more than the per-line floors allow: refused, not rounded.
      final f = bad(
        await txns.recordSaleCart(
          shopId: shopId,
          saleGroupId: 'g4',
          discount: 225.09,
          items: [
            {'product_id': a.id, 'quantity': 2.501},
            {'product_id': b.id, 'quantity': 2.501},
          ],
        ),
      );
      expect(f.code, ServerErrorCodes.discountExceedsTotal);
    });

    test('splitDiscount never gives a line more than its value', () {
      final shares = splitDiscount(
        discountCents: 10000,
        lines: [(id: 'a', value: 5000000), (id: 'b', value: 5000000)],
      );
      expect(shares.values.reduce((x, y) => x + y), 10000);
      expect(shares['a'], 5000);
    });

    test('a credit sale owes the discounted total; payments are safe', () async {
      final oil = await product('Oil', qty: 10, sell: 850, buy: 700);
      final c = ok(
        await customers.createCustomer(shopId: shopId, name: 'Rahim', phone: '017'),
      );
      ok(
        await txns.recordSaleCart(
          shopId: shopId,
          saleGroupId: 'g5',
          customerId: c.id,
          discount: 50,
          items: [
            {'product_id': oil.id, 'quantity': 1},
          ],
        ),
      );
      var balances = ok(await customers.customerBalances(shopId));
      expect(balances.single.balance, 800);

      // Overpaying is refused.
      final over = bad(
        await customers.recordPayment(
          shopId: shopId,
          customerId: c.id,
          amount: 900,
          paymentId: 'p0',
        ),
      );
      expect(over.message, startsWith('Payment exceeds balance'));

      // A retried payment is recorded once.
      for (var i = 0; i < 2; i++) {
        ok(
          await customers.recordPayment(
            shopId: shopId,
            customerId: c.id,
            amount: 300,
            paymentId: 'p1',
          ),
        );
      }
      balances = ok(await customers.customerBalances(shopId));
      expect(balances.single.balance, 500);

      // Someone who still owes cannot be deleted.
      bad(await customers.deleteCustomer(shopId: shopId, id: c.id));
      final summary = ok(await customers.receivablesSummary(shopId));
      expect(summary.totalOwed, 500);
      expect(summary.debtorCount, 1);
    });
  });

  group('deliveries', () {
    test('restock is retry-safe and joins an identical delivery', () async {
      final milk = await product('Milk', qty: 0);
      final expiry = DateTime(2026, 12, 1);
      final received = DateTime(2026, 10, 31);
      for (final id in ['r1', 'r1', 'r2']) {
        ok(
          await txns.recordRestock(
            shopId: shopId,
            productId: milk.id,
            quantity: 5,
            restockId: id,
            expiryDate: expiry,
            receivedOn: received,
          ),
        );
      }
      expect(await stock(milk.id), 10);
      final open = await db.db.query('product_batches');
      expect(open, hasLength(1));
      expect(open.single['quantity_milli'], 10000);
    });

    test('partial removal keeps the delivery open and records the loss', () async {
      final milk = await product('Milk', qty: 0, buy: 60);
      ok(
        await txns.recordRestock(
          shopId: shopId,
          productId: milk.id,
          quantity: 10,
          restockId: 'r3',
          expiryDate: DateTime(2026, 12, 1),
          receivedOn: DateTime(2026, 10, 31),
        ),
      );
      final batchId = (await db.db.query('product_batches')).single['id']! as String;
      for (var i = 0; i < 2; i++) {
        ok(
          await batches.removeStock(
            shopId: shopId,
            batchId: batchId,
            quantity: 3,
            close: false,
            removalId: 'rm1',
          ),
        );
      }
      expect(await stock(milk.id), 7);
      final b = (await db.db.query('product_batches')).single;
      expect(b['picked_qty_milli'], 3000);
      expect(b['closed_at'], isNull);
      final loss = ok(await batches.fetchRemovalLoss(milk.id));
      expect(loss.units, 3);
      expect(loss.cost, 180);
    });
  });

  test('dashboard revenue subtracts discounts; inventory value is live', () async {
    final pepsi = await product('Pepsi', qty: 10, sell: 45, buy: 30);
    ok(
      await txns.recordSaleCart(
        shopId: shopId,
        saleGroupId: 'g6',
        discount: 10,
        items: [
          {'product_id': pepsi.id, 'quantity': 2},
        ],
      ),
    );
    final s = ok(
      await AnalyticsRepository(db).getSummary(
        shopId,
        AnalyticsPeriod.today,
        utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      ),
    );
    expect(s.revenue, 80);
    expect(s.cost, 60);
    expect(s.profit, 20);
    expect(s.unitsSold, 2);
    expect(s.inventoryValue, 240);
  });

  test('a backup restores the whole shop exactly', () async {
    final pepsi = await product('Pepsi', qty: 10);
    ok(
      await txns.recordSaleCart(
        shopId: shopId,
        saleGroupId: 'g7',
        items: [
          {'product_id': pepsi.id, 'quantity': 1},
        ],
      ),
    );
    final tmp = await Directory.systemTemp.createTemp('easysell_backup');
    final photos = PhotoStore(tmp);
    final zip = await BackupService(db, photos).build();
    final info = BackupService.peek(zip);
    expect(info.shop, 'Test shop');
    expect(info.sales, 1);

    final other = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
    await BackupService(other, photos).restore(zip);
    final restored = await other.db.query('products');
    expect(restored.single['quantity_milli'], 9000);
    expect(await other.db.query('transactions'), hasLength(1));
    await other.close();
    await tmp.delete(recursive: true);
  });
}
