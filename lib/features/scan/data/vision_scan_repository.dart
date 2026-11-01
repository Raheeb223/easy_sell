import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/matching/product_matcher.dart';
import '../../inventory/domain/product.dart';
import '../domain/recognition_result.dart';
import '../domain/scan_fusion.dart';
import 'barcode_store.dart';
import 'embedding_store.dart';
import 'label_reader.dart';
import 'vision_embedder.dart';

/// A recognition plus what the photo showed, so a confirmed scan can teach
/// the model the photo (design §5a.4) and the pack's barcode.
class ScanRecognition {
  const ScanRecognition(this.result, this.embedding, {this.barcodes = const []});
  final RecognitionResult result;
  final Embedding? embedding;
  final List<String> barcodes;
}

/// Recognises a product photo entirely on the phone: EasySell Vision compares
/// the photo with the shop's taught products while ML Kit reads the label,
/// and the two are fused (design §5, §5a). A barcode the shop has seen before
/// settles it outright. Replaces the Gemini `recognize-product` function; no
/// network, typically well under a second.
class VisionScanRepository {
  VisionScanRepository(this._embedder, this._store, this._reader, this._barcodes);

  final Future<VisionEmbedder> _embedder;
  final EmbeddingStore _store;
  final LabelReader _reader;
  final BarcodeStore _barcodes;

  List<Product>? _matcherFor;
  ProductMatcher? _matcher;

  Future<Result<ScanRecognition>> recognize({
    required Uint8List imageBytes,
    required List<Product> products,
  }) async {
    try {
      final watch = Stopwatch()..start();
      var photoMs = 0, labelMs = 0;
      final photoF = _photo(imageBytes)
          .whenComplete(() => photoMs = watch.elapsedMilliseconds);
      final labelF = _label(imageBytes)
          .whenComplete(() => labelMs = watch.elapsedMilliseconds);
      final embedding = await photoF;
      final label = await labelF;

      final ids = {for (final p in products) p.id};
      final known = await _barcodes.productFor(label.barcodes);
      if (known != null && ids.contains(known)) {
        return Result.success(
          ScanRecognition(
            RecognitionResult(
              status: RecognitionStatus.match,
              matches: [ProductMatch(productId: known, confidence: 1)],
              readName: label.headline,
              readSize: QueryText.findSize(label.text),
            ),
            embedding,
            barcodes: label.barcodes,
          ),
        );
      }

      final photo = embedding == null
          ? const <String, double>{}
          : await _store.similarities(embedding.vector);
      final text = <String, double>{
        if (label.text.isNotEmpty)
          for (final s in _matcherOf(products).rank(label.text))
            s.id: s.score,
      };
      final result = fuseScan(
        productIds: ids,
        photo: photo,
        text: text,
        photoAvailable: embedding != null,
        readName: label.headline,
        readSize: QueryText.findSize(label.text),
      );
      debugPrint('scan-timing: photo ${photoMs}ms label ${labelMs}ms '
          'total ${watch.elapsedMilliseconds}ms');
      return Result.success(
        ScanRecognition(result, embedding, barcodes: label.barcodes),
      );
    } catch (e) {
      return const Result.failure(
        UnexpectedFailure('Could not recognize the product. Please try again.'),
      );
    }
  }

  /// Gets the model, ML Kit and the fingerprints ready while the camera
  /// starts, so the first scan is as fast as the rest. Never throws.
  Future<void> warmUp() => Future.wait<void>([
        _quietly(() async => (await _embedder).warmUp()),
        _quietly(_reader.warmUp),
        _quietly(() => _store.similarities(Float32List(VisionEmbedder.dim))),
      ]);

  static Future<void> _quietly(Future<Object?> Function() f) async {
    try {
      await f();
    } catch (_) {}
  }

  /// The fingerprint, or null if the model could not run (the scan then
  /// falls back to label text alone).
  Future<Embedding?> _photo(Uint8List jpeg) async {
    try {
      return await (await _embedder).embedJpeg(jpeg);
    } catch (_) {
      return null;
    }
  }

  Future<LabelText> _label(Uint8List jpeg) async {
    try {
      return await _reader.read(jpeg);
    } catch (_) {
      return LabelText.empty;
    }
  }

  ProductMatcher _matcherOf(List<Product> products) {
    if (!identical(products, _matcherFor) || _matcher == null) {
      _matcherFor = products;
      _matcher = ProductMatcher([
        for (final p in products)
          MatchTarget.of(
            id: p.id,
            name: p.name,
            brand: p.brand,
            variant: p.variant,
          ),
      ]);
    }
    return _matcher!;
  }

  /// Teaches the model that [scan] showed [productId] (a confirmed scan):
  /// the photo, and the barcode so the next scan of it is exact.
  Future<void> learn(String productId, ScanRecognition scan) async {
    for (final code in scan.barcodes) {
      await _barcodes.learn(productId, code);
    }
    if (scan.embedding case final Embedding e) {
      await _store.learn(productId, e, source: 'scan');
    }
  }
}

final visionScanRepositoryProvider = Provider<VisionScanRepository>((ref) {
  final reader = LabelReader();
  ref.onDispose(reader.close);
  return VisionScanRepository(
    ref.watch(visionEmbedderProvider.future),
    ref.watch(embeddingStoreProvider),
    reader,
    ref.watch(barcodeStoreProvider),
  );
});
