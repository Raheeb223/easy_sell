import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/local_days.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/analytics.dart';

/// Sales sums from the phone's database. Revenue is always
/// `selling_price * quantity - discount_amount` (0009), so a receipt's
/// discount is subtracted once.
///
/// Sums run on integers: `cents * milli` is 1/100000 of the currency.
///
/// [utcOffsetMinutes] is the phone's offset, so "today" and each chart day
/// start at the shop's midnight (0020).
class AnalyticsRepository {
  AnalyticsRepository(this._db);

  final AppDatabase _db;

  static const _value =
      'selling_price_cents * quantity_milli - discount_amount_cents * 1000';
  static const _profit =
      '(selling_price_cents - buying_price_cents) * quantity_milli '
      '- discount_amount_cents * 1000';

  /// `get_dashboard_summary` (0020).
  Future<Result<DashboardSummary>> getSummary(
    String shopId,
    AnalyticsPeriod period, {
    DateTime? day,
    required int utcOffsetMinutes,
    DateTime? now,
  }) async {
    try {
      final (start, end) = summaryRange(
        period,
        day: day,
        utcOffsetMinutes: utcOffsetMinutes,
        now: now,
      );
      final sales = await _db.db.rawQuery(
        '''
        SELECT COALESCE(SUM($_value), 0) AS revenue,
               COALESCE(SUM(buying_price_cents * quantity_milli), 0) AS cost,
               COALESCE(SUM($_profit), 0) AS profit,
               COALESCE(SUM(quantity_milli), 0) AS units
        FROM transactions
        WHERE shop_id = ? AND type = 'sale'
          AND created_at >= ? AND created_at < ?''',
        [shopId, start, end],
      );
      final stock = await _db.db.rawQuery(
        'SELECT COALESCE(SUM(buying_price_cents * quantity_milli), 0) AS v '
        'FROM products WHERE shop_id = ? AND is_archived = 0',
        [shopId],
      );
      final s = sales.first;
      return Result.success(
        DashboardSummary(
          revenue: _money(s['revenue']),
          cost: _money(s['cost']),
          profit: _money(s['profit']),
          unitsSold: ((s['units']! as int) / 1000).round(),
          inventoryValue: _money(stock.first['v']),
        ),
      );
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// `get_sales_series` (0020): [ChartBucket.points] local days, weeks
  /// (Monday start) or months ending with the current one; empty buckets
  /// are zero.
  Future<Result<List<SalesPoint>>> getSeries(
    String shopId,
    ChartBucket bucket, {
    required int utcOffsetMinutes,
    DateTime? now,
  }) async {
    try {
      final wall = localWallNow(utcOffsetMinutes, now: now);
      final points = bucket.points < 1 ? 1 : bucket.points;
      final current = _trunc(bucket, wall);
      final starts = <DateTime>[
        for (var i = points - 1; i >= 0; i--) _step(bucket, current, -i),
      ];
      final from = wallToUtcMicros(starts.first, utcOffsetMinutes);
      final rows = await _db.db.rawQuery(
        '''
        SELECT created_at, $_value AS revenue, $_profit AS profit
        FROM transactions
        WHERE shop_id = ? AND type = 'sale' AND created_at >= ?''',
        [shopId, from],
      );
      final revenue = List<int>.filled(points, 0);
      final profit = List<int>.filled(points, 0);
      final index = {
        for (var i = 0; i < starts.length; i++)
          starts[i].microsecondsSinceEpoch: i,
      };
      for (final r in rows) {
        final at = DateTime.fromMicrosecondsSinceEpoch(
          r['created_at']! as int,
          isUtc: true,
        ).add(Duration(minutes: utcOffsetMinutes));
        final i = index[_trunc(bucket, at).microsecondsSinceEpoch];
        if (i == null) continue;
        revenue[i] += r['revenue']! as int;
        profit[i] += r['profit']! as int;
      }
      return Result.success([
        for (var i = 0; i < points; i++)
          SalesPoint(
            bucket: DateTime.fromMicrosecondsSinceEpoch(
              wallToUtcMicros(starts[i], utcOffsetMinutes),
              isUtc: true,
            ).toLocal(),
            revenue: _money(revenue[i]),
            profit: _money(profit[i]),
          ),
      ]);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  Failure _map(Object e) =>
      const DatabaseFailure('Could not load analytics. Please try again.');
}

/// The `[start, end)` UTC-microsecond window of a summary: one local [day],
/// or [period] up to now (week starts Monday, like `date_trunc('week')`).
(int, int) summaryRange(
  AnalyticsPeriod period, {
  DateTime? day,
  required int utcOffsetMinutes,
  DateTime? now,
}) {
  const far = 1 << 62;
  if (day != null) {
    final d = dayNumber(day);
    return (
      startOfLocalDayMicros(d, utcOffsetMinutes),
      startOfLocalDayMicros(d + 1, utcOffsetMinutes),
    );
  }
  final wall = localWallNow(utcOffsetMinutes, now: now);
  final DateTime? start = switch (period) {
    AnalyticsPeriod.today => DateTime.utc(wall.year, wall.month, wall.day),
    AnalyticsPeriod.week => _trunc(ChartBucket.weekly, wall),
    AnalyticsPeriod.month => DateTime.utc(wall.year, wall.month),
    AnalyticsPeriod.all => null,
  };
  return (
    start == null ? -far : wallToUtcMicros(start, utcOffsetMinutes),
    far,
  );
}

DateTime _trunc(ChartBucket bucket, DateTime wall) {
  final day = DateTime.utc(wall.year, wall.month, wall.day);
  return switch (bucket) {
    ChartBucket.daily => day,
    ChartBucket.weekly => day.subtract(Duration(days: day.weekday - 1)),
    ChartBucket.monthly => DateTime.utc(wall.year, wall.month),
  };
}

DateTime _step(ChartBucket bucket, DateTime start, int n) => switch (bucket) {
  ChartBucket.daily => DateTime.utc(start.year, start.month, start.day + n),
  ChartBucket.weekly => DateTime.utc(start.year, start.month, start.day + 7 * n),
  ChartBucket.monthly => DateTime.utc(start.year, start.month + n),
};

/// A 1/100000-currency integer sum as money.
double _money(Object? v) => ((v as num?) ?? 0) / 100000;

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(appDatabaseProvider));
});
