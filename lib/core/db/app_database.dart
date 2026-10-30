import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'schema.dart';

/// The shop's whole database: one SQLite file on the phone (phone-only design,
/// docs/superpowers/specs/2026-10-31-phone-only-on-device-ai-design.md).
///
/// Money and quantities are stored as INTEGERS so no sum ever drifts:
///   * `*_cents` columns hold money in 1/100 of the currency (numeric(10,2)
///     in the old Postgres schema);
///   * `*_milli` columns hold quantities in 1/1000 of the unit
///     (numeric(10,3));
///   * `*_at` columns hold UTC instants as microseconds since the epoch;
///   * dates (`received_on`, `expiry_date`) are `YYYY-MM-DD` text.
/// [decodeRow] turns a stored row back into the snake_case JSON shape the
/// domain models were written against, so `Product.fromJson` etc. are unchanged.
///
/// Writes announce the tables they touched through [notify]; [watch] re-runs a
/// query whenever one of its tables changes. This replaces Supabase Realtime.
class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  final _changes = StreamController<Set<String>>.broadcast();

  static const fileName = 'easysell.db';

  /// Opens (creating if needed) the database at [path], or the app's default
  /// location. Tests pass `inMemoryDatabasePath` and an FFI [factory].
  static Future<AppDatabase> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final where = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      where,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        // Each open is its own connection (tests open several in-memory dbs).
        singleInstance: false,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          final batch = db.batch();
          for (final s in schemaStatements) {
            batch.execute(s);
          }
          await batch.commit(noResult: true);
        },
        onUpgrade: (db, from, to) async {
          for (var v = from + 1; v <= to; v++) {
            for (final s in migrations[v] ?? const <String>[]) {
              await db.execute(s);
            }
          }
        },
      ),
    );
    return AppDatabase(db);
  }

  /// Tells every [watch]er of [tables] to re-read.
  void notify(Set<String> tables) {
    if (tables.isNotEmpty && !_changes.isClosed) _changes.add(tables);
  }

  /// Emits [query]'s result now and again after every write to [tables].
  Stream<T> watch<T>(Set<String> tables, Future<T> Function() query) {
    late StreamController<T> out;
    StreamSubscription<Set<String>>? sub;
    var running = false;
    var again = false;

    Future<void> run() async {
      if (running) {
        again = true;
        return;
      }
      running = true;
      try {
        do {
          again = false;
          final value = await query();
          if (!out.isClosed) out.add(value);
        } while (again);
      } catch (e, st) {
        if (!out.isClosed) out.addError(e, st);
      } finally {
        running = false;
      }
    }

    out = StreamController<T>(
      onListen: () {
        sub = _changes.stream
            .where((changed) => changed.any(tables.contains))
            .listen((_) => run());
        run();
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  Future<void> close() async {
    await _changes.close();
    await db.close();
  }
}

/// Opened once in `main()` and injected with `overrideWithValue`.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('appDatabaseProvider must be overridden in main()'),
);

const _uuid = Uuid();

/// A fresh row id, same shape as the Postgres `gen_random_uuid()` ids.
String newId() => _uuid.v4();

/// Now, as stored: UTC microseconds since the epoch.
int nowMicros() => DateTime.now().toUtc().microsecondsSinceEpoch;

/// Money in the currency -> integer cents. Rounds the way Postgres did when a
/// value was cast to numeric(_,2) (half away from zero).
int toCents(num v) => _roundHalfAway(v * 100);

/// Quantity in units -> integer thousandths, like numeric(_,3).
int toMilli(num v) => _roundHalfAway(v * 1000);

double fromCents(int c) => c / 100;
double fromMilli(int m) => m / 1000;

int _roundHalfAway(num v) {
  // Bias by a hair so 2.501 * 1000 = 2500.9999999998 still becomes 2501.
  final x = v.toDouble();
  return x >= 0 ? (x + 1e-7).round() : -((-x + 1e-7).round());
}

/// The stored row as the snake_case JSON the domain models parse:
/// `foo_cents` -> `foo` (double), `foo_milli` -> `foo` (double), integer
/// `*_at` -> ISO-8601 UTC text, `is_*` -> bool, `image_urls` -> list.
Map<String, dynamic> decodeRow(Map<String, Object?> row) {
  final out = <String, dynamic>{};
  row.forEach((key, value) {
    if (key.endsWith('_cents')) {
      out[key.substring(0, key.length - 6)] =
          value == null ? null : (value as num) / 100;
    } else if (key.endsWith('_milli')) {
      out[key.substring(0, key.length - 6)] =
          value == null ? null : (value as num) / 1000;
    } else if (key.endsWith('_at') && value is int) {
      out[key] = DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true)
          .toIso8601String();
    } else if (key.startsWith('is_') && value is int) {
      out[key] = value != 0;
    } else if (key == 'image_urls' && value is String) {
      out[key] = decodeStringList(value);
    } else {
      out[key] = value;
    }
  });
  return out;
}

/// `image_urls` is stored as one string per line (paths and URLs never hold a
/// newline).
List<String> decodeStringList(String raw) {
  if (raw.isEmpty) return const [];
  return [
    for (final s in raw.split('\n'))
      if (s.isNotEmpty) s,
  ];
}

String encodeStringList(List<String> items) =>
    items.where((s) => s.isNotEmpty && !s.contains('\n')).join('\n');

/// An error raised by a local writer, worded exactly like the Postgres
/// function it replaces so `classifyServerMessage` keeps translating it.
class LocalDbException implements Exception {
  const LocalDbException(this.message);
  final String message;

  @override
  String toString() => message;
}
