import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/matching/product_matcher.dart';
import '../../inventory/domain/product.dart';
import '../domain/recognition_result.dart';
import '../domain/scan_fusion.dart';
import 'embedding_store.dart';
import 'label_reader.dart';
import 'vision_embedder.dart';

/// A recognition plus the photo's fingerprint, so a confirmed scan can teach
/// the model (design §5a.4).
class ScanRecognition {
  const ScanRecognition(this.result, this.embedding);
  final RecognitionResult result;
  final Embedding? embedding;
}

/// Recognises a product photo entirely on the phone: EasySell Vision compares
/// the photo with the shop's taught products while ML Kit reads the label,
/// and the two are fused (design §5, §5a). Replaces the Gemini
/// `recognize-product` function; no network, typically well under a second.
class VisionScanRepository {
  VisionScanRepository(this._embedder, this._store, this._reader);

  final Future<VisionEmbedder> _embedder;
  final EmbeddingStore _store;
  final LabelReader _reader;

  List<Product>? _matcherFor;
  ProductMatcher? _matcher;

  Future<Result<ScanRecognition>> recognize({
    required Uint8List imageBytes,
    required List<Product> products,
  }) async {
    try {
      final photoF = _photo(imageBytes);
      final labelF = _label(imageBytes);
      final embedding = await photoF;
      final label = await labelF;

      final photo = embedding == null
          ? const <String, double>{}
          : await _store.similarities(embedding.vector);
      final text = <String, double>{
        if (label.text.isNotEmpty)
          for (final s in _matcherOf(products).rank(label.text))
            s.id: s.score,
      };
      final result = fuseScan(
        productIds: products.map((p) => p.id),
        photo: photo,
        text: text,
        photoAvailable: embedding != null,
        readName: label.headline,
        readSize: QueryText.findSize(label.text),
      );
      return Result.success(ScanRecognition(result, embedding));
    } catch (e) {
      return const Result.failure(
        UnexpectedFailure('Could not recognize the product. Please try again.'),
      );
    }
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

  /// Teaches the model that [embedding] is [productId] (a confirmed scan).
  Future<void> learn(String productId, Embedding embedding) =>
      _store.learn(productId, embedding, source: 'scan');
}

final visionScanRepositoryProvider = Provider<VisionScanRepository>((ref) {
  final reader = LabelReader();
  ref.onDispose(reader.close);
  return VisionScanRepository(
    ref.watch(visionEmbedderProvider.future),
    ref.watch(embeddingStoreProvider),
    reader,
  );
});
