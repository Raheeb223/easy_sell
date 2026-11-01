import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'app_database.dart';
import 'photo_store.dart';
import 'schema.dart';

/// The one-file backup (design §4.1): every table plus the product photos,
/// zipped. The shopkeeper keeps it wherever they like (Drive, WhatsApp to
/// themselves, a PC); nothing is uploaded by the app.
///
/// Rows are stored exactly as in SQLite (integer cents/milli/micros), so a
/// restore is a straight copy and cannot round anything.
class BackupService {
  BackupService(this._db, this._photos);

  final AppDatabase _db;
  final PhotoStore _photos;

  static const format = 'easysell-backup';
  static const version = 1;

  /// Insert order respects foreign keys; deletes run in reverse.
  static const tables = [
    'shops',
    'categories',
    'products',
    'product_batches',
    'transactions',
    'customers',
    'customer_ledger',
    'product_embeddings',
    'product_aliases',
  ];

  static const _blobColumns = {'vector'};

  /// Builds the backup and returns the zip bytes.
  Future<Uint8List> build() async {
    final data = <String, Object?>{
      'format': format,
      'version': version,
      'schema': schemaVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    final rows = <String, List<Map<String, Object?>>>{};
    await _db.db.transaction((txn) async {
      for (final t in tables) {
        final r = await txn.query(t);
        rows[t] = [
          for (final row in r)
            {
              for (final e in row.entries)
                e.key: _blobColumns.contains(e.key) && e.value is Uint8List
                    ? base64Encode(e.value! as Uint8List)
                    : e.value,
            },
        ];
      }
    });
    data['tables'] = rows;

    final archive = Archive();
    final json = utf8.encode(jsonEncode(data));
    archive.addFile(ArchiveFile('easysell.json', json.length, json));
    if (await _photos.dir.exists()) {
      await for (final f in _photos.dir.list()) {
        if (f is! File) continue;
        final bytes = await f.readAsBytes();
        // Stored, not deflated: JPEGs are already compressed.
        archive.addFile(
          ArchiveFile.noCompress(
            p.posix.join(PhotoStore.folder, p.basename(f.path)),
            bytes.length,
            bytes,
          ),
        );
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// A short summary of a backup file, shown before restoring over the shop.
  static ({String shop, int products, int sales, DateTime? createdAt}) peek(
    Uint8List zip,
  ) {
    final data = _read(zip);
    final t = data['tables'] as Map<String, dynamic>;
    final shops = t['shops'] as List;
    return (
      shop: shops.isEmpty ? '' : (shops.first as Map)['name'] as String,
      products: (t['products'] as List).length,
      sales: (t['transactions'] as List)
          .where((r) => (r as Map)['type'] == 'sale')
          .length,
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? ''),
    );
  }

  /// Replaces EVERYTHING on this phone with the backup, in one transaction.
  Future<void> restore(Uint8List zip) async {
    final data = _read(zip);
    final archive = ZipDecoder().decodeBytes(zip);
    final t = data['tables'] as Map<String, dynamic>;

    await _db.db.transaction((txn) async {
      for (final name in tables.reversed) {
        await txn.delete(name);
      }
      for (final name in tables) {
        for (final row in (t[name] as List? ?? const [])) {
          final m = Map<String, Object?>.from(row as Map);
          for (final c in _blobColumns) {
            if (m[c] is String) m[c] = base64Decode(m[c]! as String);
          }
          await txn.insert(name, m);
        }
      }
    });

    if (await _photos.dir.exists()) await _photos.dir.delete(recursive: true);
    await _photos.dir.create(recursive: true);
    for (final f in archive.files) {
      if (!f.isFile || !f.name.startsWith('${PhotoStore.folder}/')) continue;
      await File(
        _photos.resolve(f.name),
      ).writeAsBytes(f.content, flush: true);
    }
    _db.notify(tables.toSet());
  }

  static Map<String, dynamic> _read(Uint8List zip) {
    final archive = ZipDecoder().decodeBytes(zip);
    final entry = archive.findFile('easysell.json');
    if (entry == null) throw const FormatException('Not an EasySell backup');
    final data = jsonDecode(utf8.decode(entry.content)) as Map<String, dynamic>;
    if (data['format'] != format) {
      throw const FormatException('Not an EasySell backup');
    }
    if ((data['schema'] as int? ?? 0) > schemaVersion) {
      throw const FormatException('Backup is from a newer app version');
    }
    return data;
  }
}
