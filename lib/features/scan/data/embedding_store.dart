import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/photo_store.dart';
import 'vision_embedder.dart';

/// Most fingerprints kept per product. Enrolled photos are kept first; the
/// oldest learned-from-scan ones are dropped past this (design §5a.4).
const maxFingerprintsPerProduct = 20;

/// The products' photo fingerprints, held in memory for instant matching
/// (a few thousand 256-number dot products: well under 10 ms).
class EmbeddingStore {
  EmbeddingStore(this._db, this._photos);

  final AppDatabase _db;
  final PhotoStore _photos;

  Map<String, List<Float32List>>? _cache;

  void invalidate() => _cache = null;

  Future<Map<String, List<Float32List>>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final rows = await _db.db.rawQuery(
      'SELECT e.product_id, e.vector FROM product_embeddings e '
      'JOIN products p ON p.id = e.product_id '
      'WHERE p.is_archived = 0 AND e.model = ?',
      [VisionEmbedder.modelId],
    );
    final out = <String, List<Float32List>>{};
    for (final r in rows) {
      final blob = r['vector']! as Uint8List;
      // Copied so the float view is 4-byte aligned whatever sqflite returns.
      final v = Float32List.view(Uint8List.fromList(blob).buffer);
      out.putIfAbsent(r['product_id']! as String, () => []).add(v);
    }
    return _cache = out;
  }

  /// Best cosine similarity of [query] to each taught product.
  Future<Map<String, double>> similarities(Float32List query) async {
    final all = await _load();
    final out = <String, double>{};
    for (final e in all.entries) {
      var best = -1.0;
      for (final v in e.value) {
        var s = 0.0;
        for (var i = 0; i < v.length; i++) {
          s += v[i] * query[i];
        }
        if (s > best) best = s;
      }
      out[e.key] = best;
    }
    return out;
  }

  /// How many photos each product has been taught with.
  Future<Map<String, int>> counts() async {
    final all = await _load();
    return {for (final e in all.entries) e.key: e.value.length};
  }

  /// Teaches [productId] one more photo. [source] is `enroll` (the
  /// shopkeeper took it to teach) or `scan` (a scan they confirmed).
  Future<void> learn(
    String productId,
    Embedding embedding, {
    required String source,
  }) async {
    final id = newId();
    final thumb = await _photos.save(embedding.thumbJpeg, 'fp_$id.jpg');
    final dropped = <String>[];
    await _db.db.transaction((txn) async {
      await txn.insert('product_embeddings', {
        'id': id,
        'product_id': productId,
        'model': VisionEmbedder.modelId,
        'vector': embedding.vector.buffer.asUint8List(
          embedding.vector.offsetInBytes,
          embedding.vector.lengthInBytes,
        ),
        'source': source,
        'thumb_path': thumb,
        'created_at': nowMicros(),
      });
      // Over the cap: drop the oldest learned-from-scan fingerprints first,
      // then the oldest enrolled ones.
      final extra = await txn.rawQuery(
        'SELECT id, thumb_path FROM product_embeddings WHERE product_id = ? '
        "ORDER BY CASE source WHEN 'scan' THEN 0 ELSE 1 END, created_at "
        'LIMIT max(0, (SELECT COUNT(*) FROM product_embeddings '
        'WHERE product_id = ?) - ?)',
        [productId, productId, maxFingerprintsPerProduct],
      );
      for (final r in extra) {
        await txn.delete(
          'product_embeddings',
          where: 'id = ?',
          whereArgs: [r['id']],
        );
        if (r['thumb_path'] case final String t) dropped.add(t);
      }
    });
    for (final t in dropped) {
      await _photos.delete(t);
    }
    invalidate();
    _db.notify({'product_embeddings'});
  }

  /// The taught photos of a product, newest first (for the product screen).
  Future<List<TaughtPhoto>> photosOf(String productId) async {
    final rows = await _db.db.query(
      'product_embeddings',
      columns: ['id', 'thumb_path', 'source'],
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
    return [
      for (final r in rows)
        TaughtPhoto(
          id: r['id']! as String,
          path: r['thumb_path'] == null
              ? null
              : _photos.resolve(r['thumb_path']! as String),
          fromScan: r['source'] == 'scan',
        ),
    ];
  }

  Future<void> forget(String fingerprintId) async {
    final rows = await _db.db.query(
      'product_embeddings',
      columns: ['thumb_path'],
      where: 'id = ?',
      whereArgs: [fingerprintId],
    );
    await _db.db.delete(
      'product_embeddings',
      where: 'id = ?',
      whereArgs: [fingerprintId],
    );
    final thumb = rows.isEmpty ? null : rows.first['thumb_path'] as String?;
    if (thumb != null) await _photos.delete(thumb);
    invalidate();
    _db.notify({'product_embeddings'});
  }
}

extension ModelUpgrade on EmbeddingStore {
  /// Re-embeds fingerprints made by an older model from their saved
  /// thumbnails, so a model update never mixes two fingerprint spaces and
  /// the shopkeeper never re-takes photos.
  Future<void> upgradeTo(VisionEmbedder embedder) async {
    final rows = await _db.db.query(
      'product_embeddings',
      columns: ['id', 'thumb_path'],
      where: 'model != ? AND thumb_path IS NOT NULL',
      whereArgs: [VisionEmbedder.modelId],
    );
    if (rows.isEmpty) return;
    for (final r in rows) {
      try {
        final bytes = await File(
          _photos.resolve(r['thumb_path']! as String),
        ).readAsBytes();
        final e = await embedder.embedJpeg(bytes);
        await _db.db.update(
          'product_embeddings',
          {
            'model': VisionEmbedder.modelId,
            'vector': e.vector.buffer.asUint8List(),
          },
          where: 'id = ?',
          whereArgs: [r['id']],
        );
      } catch (_) {
        // A missing thumbnail only loses that one fingerprint.
      }
    }
    invalidate();
    _db.notify({'product_embeddings'});
  }
}

class TaughtPhoto {
  const TaughtPhoto({required this.id, this.path, required this.fromScan});
  final String id;
  final String? path;
  final bool fromScan;
}

final embeddingStoreProvider = Provider<EmbeddingStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final store = EmbeddingStore(db, ref.watch(photoStoreProvider));
  // A restore or archive changes which fingerprints count.
  final sub = db
      .watch({'product_embeddings', 'products'}, () async => null)
      .listen((_) => store.invalidate());
  ref.onDispose(sub.cancel);
  return store;
});

/// How many photos each product has been taught with, live.
final taughtCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watch({'product_embeddings'}, () async {
    final rows = await db.db.rawQuery(
      'SELECT product_id, COUNT(*) AS n FROM product_embeddings '
      'WHERE model = ? GROUP BY product_id',
      [VisionEmbedder.modelId],
    );
    return {
      for (final r in rows) r['product_id']! as String: r['n']! as int,
    };
  });
});

/// The model, loaded once in the background on first use.
final visionEmbedderProvider = FutureProvider<VisionEmbedder>((ref) async {
  final e = await VisionEmbedder.load();
  ref.onDispose(e.dispose);
  // In the background: bring fingerprints from an older model up to date.
  ref.read(embeddingStoreProvider).upgradeTo(e).ignore();
  return e;
});
