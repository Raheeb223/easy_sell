import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/local_days.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/cash_flow_alerts.dart';
import '../domain/finance_health.dart';

/// Port of `get_finance_health` (0019): plain sums over the last 90 local
/// days plus FIFO-aged khata debt. Every judgement on these sums is made in
/// `cash_flow_alerts.dart` / `financing_match.dart`, unchanged.
class FinanceRepository {
  FinanceRepository(this._db);

  final AppDatabase _db;

  Future<Result<FinanceHealth>> fetchHealth(
    String shopId, {
    required DateTime today,
    required int utcOffsetMinutes,
  }) async {
    try {
      final t = dayNumber(today);
      final off = utcOffsetMinutes;
      final since = startOfLocalDayMicros(t - 92, off);

      final saleRows = await _db.db.rawQuery(
        '''
        SELECT t.created_at,
          t.selling_price_cents * t.quantity_milli - t.discount_amount_cents * 1000 AS net,
          (t.selling_price_cents - t.buying_price_cents) * t.quantity_milli
            - t.discount_amount_cents * 1000 AS profit,
          CASE
            WHEN t.payment_method = 'credit' THEN 'credit'
            WHEN t.payment_method = 'digital' THEN 'digital'
            WHEN t.payment_method IS NULL AND EXISTS (
              SELECT 1 FROM customer_ledger l
              WHERE l.shop_id = t.shop_id AND l.entry_type = 'credit_sale'
                AND l.sale_group_id = t.sale_group_id) THEN 'credit'
            ELSE 'cash'
          END AS method
        FROM transactions t
        WHERE t.shop_id = ? AND t.type = 'sale' AND t.created_at >= ?''',
        [shopId, since],
      );
      final restockRows = await _db.db.rawQuery(
        "SELECT created_at, buying_price_cents * quantity_milli AS spend "
        "FROM transactions WHERE shop_id = ? AND type = 'restock' "
        "AND created_at >= ?",
        [shopId, since],
      );
      final ledgerRows = await _db.db.rawQuery(
        'SELECT l.id, l.customer_id, l.entry_type, l.amount_cents, l.created_at, '
        'c.name FROM customer_ledger l JOIN customers c ON c.id = l.customer_id '
        'WHERE l.shop_id = ? ORDER BY l.created_at, l.id',
        [shopId],
      );
      final first = await _db.db.rawQuery(
        'SELECT MIN(created_at) AS m FROM transactions WHERE shop_id = ?',
        [shopId],
      );

      // Sales sums, in 1/100000 currency.
      var cash7 = 0, digital7 = 0, credit7 = 0, week = 0, prevWeek = 0;
      var sales90 = 0, profit90 = 0, digital90 = 0;
      final activeWeeks = <int>{};
      for (final r in saleRows) {
        final d = localDayOf(r['created_at']! as int, off);
        final net = r['net']! as int;
        final method = r['method']! as String;
        if (d >= t - 6 && d <= t) {
          switch (method) {
            case 'cash':
              cash7 += net;
            case 'digital':
              digital7 += net;
            default:
              credit7 += net;
          }
        }
        if (d >= t - 7 && d <= t - 1) week += net;
        if (d >= t - 14 && d <= t - 8) prevWeek += net;
        if (d >= t - 89 && d <= t) {
          sales90 += net;
          profit90 += r['profit']! as int;
          if (method == 'digital') digital90 += net;
        }
        if (d >= t - 83 && d <= t) activeWeeks.add((t - d) ~/ 7);
      }

      var spend7 = 0, spend90 = 0;
      for (final r in restockRows) {
        final d = localDayOf(r['created_at']! as int, off);
        final spend = r['spend']! as int;
        if (d >= t - 6 && d <= t) spend7 += spend;
        if (d >= t - 89 && d <= t) spend90 += spend;
      }

      // Khata, in cents. Ledger rows are oldest first.
      var collected7 = 0, owedWeekAgo = 0;
      final balance = <String, int>{};
      final paid = <String, int>{};
      final names = <String, String>{};
      for (final r in ledgerRows) {
        final id = r['customer_id']! as String;
        final amount = r['amount_cents']! as int;
        final credit = r['entry_type'] == 'credit_sale';
        final d = localDayOf(r['created_at']! as int, off);
        names[id] = r['name']! as String;
        balance[id] = (balance[id] ?? 0) + (credit ? amount : -amount);
        if (!credit) {
          paid[id] = (paid[id] ?? 0) + amount;
          if (d >= t - 6 && d <= t) collected7 += amount;
        }
        if (d < t - 6) owedWeekAgo += credit ? amount : -amount;
      }

      // FIFO ageing: payments cover the oldest credit first; the first credit
      // not fully covered is how old the debt is.
      final oldestUnpaid = <String, int>{};
      final running = <String, int>{};
      for (final r in ledgerRows) {
        if (r['entry_type'] != 'credit_sale') continue;
        final id = r['customer_id']! as String;
        running[id] = (running[id] ?? 0) + (r['amount_cents']! as int);
        if (running[id]! > (paid[id] ?? 0) && !oldestUnpaid.containsKey(id)) {
          oldestUnpaid[id] = localDayOf(r['created_at']! as int, off);
        }
      }
      final overdue = <({String name, int balance, int days})>[
        for (final e in oldestUnpaid.entries)
          if ((balance[e.key] ?? 0) > 0 && t - e.value >= overdueDays)
            (name: names[e.key]!, balance: balance[e.key]!, days: t - e.value),
      ]..sort((a, b) {
          final byBalance = b.balance.compareTo(a.balance);
          return byBalance != 0 ? byBalance : b.days.compareTo(a.days);
        });
      final top = overdue.isEmpty ? null : overdue.first;

      final firstAt = first.first['m'] as int?;
      return Result.success(
        FinanceHealth(
          cashSales7d: _u(cash7),
          digitalSales7d: _u(digital7),
          creditSales7d: _u(credit7),
          collected7d: collected7 / 100,
          restockSpend7d: _u(spend7),
          salesWeek: _u(week),
          salesPrevWeek: _u(prevWeek),
          owedNow: balance.values.fold<int>(0, (s, b) => s + b) / 100,
          owedWeekAgo: owedWeekAgo / 100,
          overdueCount: overdue.length,
          overdueTopName: top?.name,
          overdueTopBalance: top == null ? null : top.balance / 100,
          overdueTopDays: top?.days,
          sales90d: _u(sales90),
          profit90d: _u(profit90),
          digitalSales90d: _u(digital90),
          restockSpend90d: _u(spend90),
          activeWeeks12: activeWeeks.length,
          tradingDays: firstAt == null ? 0 : t - localDayOf(firstAt, off) + 1,
        ),
      );
    } catch (e) {
      return const Result.failure(
        DatabaseFailure('Could not load money health. Please try again.'),
      );
    }
  }
}

double _u(int v) => v / 100000;

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(appDatabaseProvider)),
);
