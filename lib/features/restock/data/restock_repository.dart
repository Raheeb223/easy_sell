import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/local_days.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/restock_plan.dart';

/// Port of `get_restock_speeds` (0017). Per product: units per in-stock day
/// over the 28 full local days ending yesterday, weeks weighted
/// 0.4/0.3/0.2/0.1. A day counts only if the product could be sold: unexpired
/// stock at the start of the day, or a sale that day (its creation day only if
/// it sold). Start-of-day stock is rebuilt backwards from today's stock.
class RestockRepository {
  RestockRepository(this._db);

  final AppDatabase _db;

  Future<Result<List<RestockSpeed>>> fetchSpeeds(
    String shopId, {
    required DateTime today,
    required int utcOffsetMinutes,
  }) async {
    try {
      final t = dayNumber(today);
      final off = utcOffsetMinutes;
      final products = await _db.db.rawQuery(
        'SELECT id, quantity_milli, created_at FROM products '
        'WHERE shop_id = ? AND is_archived = 0',
        [shopId],
      );
      final txns = await _db.db.rawQuery(
        'SELECT product_id, type, quantity_milli, created_at FROM transactions '
        'WHERE shop_id = ? AND created_at >= ?',
        [shopId, startOfLocalDayMicros(t - 30, off)],
      );
      final expired = await _db.db.rawQuery(
        'SELECT product_id, expired_qty_milli, expiry_date, closed_at '
        'FROM product_batches WHERE shop_id = ? AND expired_qty_milli IS NOT NULL',
        [shopId],
      );

      // Per product per local day (>= t-28): net change and units sold.
      final net = <String, Map<int, int>>{};
      final sold = <String, Map<int, int>>{};
      for (final r in txns) {
        final d = localDayOf(r['created_at']! as int, off);
        if (d < t - 28) continue;
        final id = r['product_id']! as String;
        final q = r['quantity_milli']! as int;
        final type = r['type']! as String;
        net.putIfAbsent(id, () => {})[d] =
            (net[id]![d] ?? 0) + (type == 'restock' ? q : -q);
        if (type == 'sale') {
          sold.putIfAbsent(id, () => {})[d] = (sold[id]![d] ?? 0) + q;
        }
      }

      final out = <RestockSpeed>[];
      for (final p in products) {
        final id = p['id']! as String;
        final created = localDayOf(p['created_at']! as int, off);
        final pn = net[id] ?? const <int, int>{};
        final ps = sold[id] ?? const <int, int>{};
        var after = 0;
        pn.forEach((d, n) {
          if (d >= t) after += n;
        });

        final units = List<int>.filled(4, 0);
        final inDays = List<int>.filled(4, 0);
        // Walk the window newest-first so the running net is a suffix sum.
        var suffix = 0;
        for (var d = t - 1; d >= t - 28; d--) {
          suffix += pn[d] ?? 0;
          final start = (p['quantity_milli']! as int) - after - suffix;
          var exp = 0;
          for (final b in expired) {
            if (b['product_id'] != id) continue;
            if (dayNumberOfYmd(b['expiry_date']! as String) >= d) continue;
            final closed = b['closed_at'] as int?;
            if (closed != null && localDayOf(closed, off) < d) continue;
            exp += b['expired_qty_milli']! as int;
          }
          final s = ps[d] ?? 0;
          final w = (t - 1 - d) ~/ 7;
          units[w] += s;
          if ((d > created && start - exp > 0) || (d >= created && s > 0)) {
            inDays[w]++;
          }
        }

        const weights = [0.4, 0.3, 0.2, 0.1];
        var num = 0.0, den = 0.0;
        double? week0;
        for (var w = 0; w < 4; w++) {
          if (inDays[w] == 0) continue;
          final rate = units[w] / 1000 / inDays[w];
          num += rate * weights[w];
          den += weights[w];
          if (w == 0) week0 = rate;
        }
        if (num > 0) {
          out.add(RestockSpeed(productId: id, speed: num / den, week0Rate: week0));
        }
      }
      return Result.success(out);
    } catch (e) {
      return const Result.failure(
        DatabaseFailure('Could not work out restock speeds. Please try again.'),
      );
    }
  }
}

final restockRepositoryProvider = Provider<RestockRepository>(
  (ref) => RestockRepository(ref.watch(appDatabaseProvider)),
);
