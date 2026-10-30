/// Local-day arithmetic for the report ports. The Postgres functions cut days
/// at the PHONE's midnight using a fixed `p_utc_offset_minutes` (0020); these
/// helpers do the same on stored UTC microseconds.
///
/// A "day number" is whole days since 1970-01-01 on the local calendar, so
/// `today - 6` means the same as `p_today - 6` in SQL.
library;

const _microsPerDay = 86400000000;
const _microsPerMinute = 60000000;

/// The local day number of a stored instant.
int localDayOf(int createdAtMicros, int utcOffsetMinutes) {
  final shifted = createdAtMicros + utcOffsetMinutes * _microsPerMinute;
  return (shifted / _microsPerDay).floor();
}

/// The day number of a calendar date (its time is ignored).
int dayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    86400000;

/// The day number of a `YYYY-MM-DD` text date.
int dayNumberOfYmd(String ymd) => dayNumber(DateTime.parse(ymd));

/// The UTC instant (microseconds) at which local day [day] starts.
int startOfLocalDayMicros(int day, int utcOffsetMinutes) =>
    day * _microsPerDay - utcOffsetMinutes * _microsPerMinute;

/// The phone's wall clock now, as a UTC-flagged [DateTime] holding local
/// fields (the SQL `(now() at time zone 'UTC') + offset`).
DateTime localWallNow(int utcOffsetMinutes, {DateTime? now}) =>
    (now ?? DateTime.now()).toUtc().add(Duration(minutes: utcOffsetMinutes));

/// The UTC instant (microseconds) a wall-clock value stands for.
int wallToUtcMicros(DateTime wall, int utcOffsetMinutes) =>
    wall.microsecondsSinceEpoch - utcOffsetMinutes * _microsPerMinute;
