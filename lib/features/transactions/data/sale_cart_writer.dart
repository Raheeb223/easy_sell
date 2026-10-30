import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

import '../../../core/db/app_database.dart';

/// Port of `record_sale_cart` (migrations 0007–0018). Runs inside the
/// caller's SQLite transaction; any [LocalDbException] rolls back every line.
///
/// All arithmetic is on integers: prices in cents, quantities in thousandths,
/// so a line's value `cents * milli` is in 1/100000 of the currency and the
/// discount split floors exactly as the Postgres `numeric` version did.
///
/// Returns nothing: the caller reads the group back.
Future<void> writeSaleCart(
  DatabaseExecutor txn, {
  required String shopId,
  required List<Map<String, dynamic>> items,
  required String group,
  required String source,
  required String? customerId,
  required int discountCents,
  required String method,
}) async {
  // Replay: this id was already recorded, so change nothing. (SQLite runs one
  // write transaction at a time, which is what the advisory lock did.)
  final existing = await txn.rawQuery(
    'SELECT 1 FROM transactions WHERE shop_id = ? AND sale_group_id = ? LIMIT 1',
    [shopId, group],
  );
  if (existing.isNotEmpty) return;

  if (items.isEmpty) throw const LocalDbException('Cart is empty');

  final String paidBy;
  if (customerId != null) {
    final c = await txn.rawQuery(
      'SELECT 1 FROM customers WHERE id = ? AND shop_id = ?',
      [customerId, shopId],
    );
    if (c.isEmpty) throw const LocalDbException('Customer not found');
    paidBy = 'credit';
  } else {
    if (method != 'cash' && method != 'digital') {
      throw LocalDbException('Unknown payment method: $method');
    }
    paidBy = method;
  }

  final now = nowMicros();
  for (final item in items) {
    final productId = item['product_id'] as String;
    final qty = toMilli((item['quantity'] as num?) ?? 0);
    final batchId = item['batch_id'] as String?;
    if (qty <= 0) {
      throw const LocalDbException('Quantity must be greater than zero');
    }

    final products = await txn.rawQuery(
      'SELECT name, quantity_milli, buying_price_cents, selling_price_cents '
      'FROM products WHERE id = ? AND shop_id = ?',
      [productId, shopId],
    );
    if (products.isEmpty) throw const LocalDbException('Product not found');
    final product = products.first;
    final have = product['quantity_milli']! as int;
    if (have < qty) {
      throw LocalDbException(
        'Insufficient stock for ${product['name']}: '
        'have ${_qty(have)}, need ${_qty(qty)}',
      );
    }

    // The delivery this line was picked from: same shop and product, open,
    // not locked as expired, and not picked past what was delivered.
    if (batchId != null) {
      final b = await txn.rawQuery(
        'SELECT quantity_milli, picked_qty_milli, closed_at, expired_qty_milli '
        'FROM product_batches WHERE id = ? AND shop_id = ? AND product_id = ?',
        [batchId, shopId, productId],
      );
      if (b.isEmpty ||
          b.first['closed_at'] != null ||
          b.first['expired_qty_milli'] != null ||
          (b.first['picked_qty_milli']! as int) + qty >
              (b.first['quantity_milli']! as int)) {
        throw const LocalDbException('Batch not available');
      }
      await txn.rawUpdate(
        'UPDATE product_batches SET picked_qty_milli = picked_qty_milli + ? '
        'WHERE id = ?',
        [qty, batchId],
      );
    }

    await txn.rawUpdate(
      'UPDATE products SET quantity_milli = quantity_milli - ?, updated_at = ? '
      'WHERE id = ?',
      [qty, now, productId],
    );
    await txn.insert('transactions', {
      'id': newId(),
      'shop_id': shopId,
      'product_id': productId,
      'type': 'sale',
      'quantity_milli': qty,
      'buying_price_cents': product['buying_price_cents'],
      'selling_price_cents': product['selling_price_cents'],
      'source': source,
      'sale_group_id': group,
      'batch_id': batchId,
      'payment_method': paidBy,
      'created_at': now,
    });
  }

  if (discountCents < 0) {
    throw const LocalDbException('Discount cannot be negative');
  }

  final lines = await txn.rawQuery(
    'SELECT id, selling_price_cents * quantity_milli AS value '
    'FROM transactions WHERE sale_group_id = ? AND shop_id = ?',
    [group, shopId],
  );

  final shares = <String, int>{};
  if (discountCents > 0) {
    final shared = splitDiscount(
      discountCents: discountCents,
      lines: [
        for (final l in lines) (id: l['id']! as String, value: l['value']! as int),
      ],
    );
    for (final s in shared.entries) {
      if (s.value > 0) {
        await txn.rawUpdate(
          'UPDATE transactions SET discount_amount_cents = ? WHERE id = ?',
          [s.value, s.key],
        );
      }
    }
    shares.addAll(shared);
  }

  // On credit the debt is the DISCOUNTED total, rounded once to cents. A
  // discount equal to the whole bill leaves no debt and no ledger row.
  if (customerId != null) {
    var total = 0; // 1/100000 currency
    for (final l in lines) {
      total += (l['value']! as int) - (shares[l['id']] ?? 0) * 1000;
    }
    final owed = (total + 500) ~/ 1000;
    if (owed > 0) {
      await txn.insert('customer_ledger', {
        'id': newId(),
        'shop_id': shopId,
        'customer_id': customerId,
        'entry_type': 'credit_sale',
        'amount_cents': owed,
        'sale_group_id': group,
        'created_at': now,
      });
    }
  }
}

/// The largest discount a cart can carry, in cents: the sum of each line's
/// value floored to cents (0009's `v_max`). Line values are in 1/100000.
int maxDiscountCents(Iterable<int> lineValues) =>
    lineValues.fold(0, (sum, v) => sum + v ~/ 1000);

/// Splits [discountCents] across [lines] in proportion to their value,
/// flooring each share to cents and handing the leftover paisa out
/// largest-line-first (0009/0018). The shares always sum to the discount and
/// no share exceeds its line.
Map<String, int> splitDiscount({
  required int discountCents,
  required List<({String id, int value})> lines,
}) {
  final max = maxDiscountCents(lines.map((l) => l.value));
  if (discountCents > max) {
    throw LocalDbException(
      'Discount exceeds total: most you can take off is '
      '${(max / 100).toStringAsFixed(2)}, asked for '
      '${(discountCents / 100).toStringAsFixed(2)}',
    );
  }
  final subtotal = lines.fold<int>(0, (s, l) => s + l.value);
  final shares = <String, int>{};
  var assigned = 0;
  for (final l in lines) {
    // floor(discount * value / subtotal) in cents; BigInt so a big bill
    // cannot overflow the product.
    final share = subtotal == 0
        ? 0
        : (BigInt.from(discountCents) * BigInt.from(l.value) ~/
                  BigInt.from(subtotal))
              .toInt();
    shares[l.id] = share;
    assigned += share;
  }
  var left = discountCents - assigned;
  final ordered = [...lines]
    ..sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      return byValue != 0 ? byValue : a.id.compareTo(b.id);
    });
  for (final l in ordered) {
    if (left <= 0) break;
    final room = l.value ~/ 1000 - shares[l.id]!;
    final give = left < room ? left : room;
    if (give > 0) {
      shares[l.id] = shares[l.id]! + give;
      left -= give;
    }
  }
  return shares;
}

/// A thousandths quantity as Postgres printed numeric(10,3): `3.000`, `2.500`.
String _qty(int milli) => (milli / 1000).toStringAsFixed(3);
