import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../../core/db/app_database.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../inventory/domain/product.dart';
import '../domain/sale_parser.dart';
import '../domain/voice_parse_result.dart';

/// Understands a spoken sale on the phone (design §6): the on-device parser
/// against the shop's products and the words this shop has taught it.
/// Replaces the Gemini `parse-sale` function; no network, a few ms.
class VoiceSaleRepository {
  VoiceSaleRepository(this._db);

  final AppDatabase _db;

  /// Parses [transcript] (and the recogniser's [alternatives]) against
  /// [products]. [recentUnits] (last 30 days) only break real ties.
  Future<Result<VoiceParseResult>> parseTranscript({
    required String transcript,
    required List<Product> products,
    List<String> alternatives = const [],
    Map<String, double> recentUnits = const {},
  }) async {
    try {
      final aliases = await _aliases();
      final parser = SaleParser(
        products: [
          for (final p in products)
            ParserProduct(
              id: p.id,
              name: p.name,
              brand: p.brand,
              variant: p.variant,
              unit: p.unit.name,
              aliases: aliases[p.id] ?? const [],
            ),
        ],
        recentUnits: recentUnits,
      );
      return Result.success(
        parser.parse(transcript, alternatives: alternatives),
      );
    } catch (_) {
      return const Result.failure(
        UnexpectedFailure('Could not understand that. Please try again.'),
      );
    }
  }

  /// Phrases to bias the recogniser toward: product names and taught words.
  Future<List<String>> hints(List<Product> products) async {
    final aliases = await _aliases();
    return {
      for (final p in products) ...[
        p.name,
        if (p.brand != null && p.brand!.isNotEmpty) p.brand!,
        ...?aliases[p.id],
      ],
    }.toList();
  }

  /// The shopkeeper said [phrase] and meant [productId]: remember it, so the
  /// same words find that product straight away next time (design §5a).
  Future<void> learnAlias(String productId, String phrase) async {
    final norm = normalizePhrase(phrase);
    if (norm.isEmpty || norm.length > 60) return;
    final now = nowMicros();
    await _db.db.transaction((txn) async {
      final updated = await txn.rawUpdate(
        'UPDATE product_aliases SET hits = hits + 1, updated_at = ? '
        'WHERE product_id = ? AND phrase_normalized = ?',
        [now, productId, norm],
      );
      if (updated == 0) {
        await txn.insert('product_aliases', {
          'id': newId(),
          'product_id': productId,
          'phrase': phrase.trim(),
          'phrase_normalized': norm,
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      // The same words now mean this product: drop them from any other.
      await txn.delete(
        'product_aliases',
        where: 'phrase_normalized = ? AND product_id != ?',
        whereArgs: [norm, productId],
      );
    });
    _cache = null;
    _db.notify({'product_aliases'});
  }

  Map<String, List<String>>? _cache;

  void invalidate() => _cache = null;

  Future<Map<String, List<String>>> _aliases() async {
    final cached = _cache;
    if (cached != null) return cached;
    final rows = await _db.db.query(
      'product_aliases',
      columns: ['product_id', 'phrase'],
    );
    final out = <String, List<String>>{};
    for (final r in rows) {
      out.putIfAbsent(r['product_id']! as String, () => []).add(
        r['phrase']! as String,
      );
    }
    return _cache = out;
  }
}

final voiceSaleRepositoryProvider = Provider<VoiceSaleRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = VoiceSaleRepository(db);
  // A restored backup brings its own taught words.
  final sub = db
      .watch({'product_aliases'}, () async => null)
      .listen((_) => repo.invalidate());
  ref.onDispose(sub.cancel);
  return repo;
});
