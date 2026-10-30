import 'dart:math' as math;

import 'recognition_result.dart';

/// How the photo and the label text are weighed (design §5 + §5a.5).
///
/// Each product gets a logit `photoWeight * similarity + textWeight * text`,
/// next to a "none of these" logit at the thresholds; a softmax turns them
/// into the confidences `decideScanAction` already thresholds (0.80 to sell,
/// 0.50 to ask). The photo identifies the product family and Bangla-only or
/// loose items; the text separates sizes the photo mixes up.
///
/// [photoThreshold] is the cosine similarity at which a photo match is as
/// likely right as wrong for a 200-product shop; it is calibrated from the
/// few-shot test in `ml/` (see `ml/README.md`) and shipped with the model.
class FusionParams {
  const FusionParams({
    this.photoWeight = 24,
    this.photoThreshold = 0.55,
    this.textWeight = 9,
    this.textThreshold = 0.55,
    this.untaughtSimilarity = 0.25,
  });

  final double photoWeight;
  final double photoThreshold;
  final double textWeight;
  final double textThreshold;

  /// What an untaught product counts as on the photo side: well below a
  /// match, so it wins only on its label text.
  final double untaughtSimilarity;
}

/// Combines per-product photo similarity and label-text score.
///
/// [photo] holds the best cosine similarity for taught products (missing
/// when no photo model ran); [text] holds 0..1 label scores. Returns up to
/// [limit] matches, best first, as a [RecognitionResult].
RecognitionResult fuseScan({
  required Iterable<String> productIds,
  required Map<String, double> photo,
  required Map<String, double> text,
  bool photoAvailable = true,
  FusionParams params = const FusionParams(),
  String? readName,
  String? readSize,
  int limit = 5,
}) {
  final logits = <String, double>{};
  final usePhoto = photoAvailable && photo.isNotEmpty;
  for (final id in productIds) {
    var l = 0.0;
    if (usePhoto) {
      final s = photo[id] ?? params.untaughtSimilarity;
      l += params.photoWeight * (s - params.photoThreshold);
    }
    final t = text[id] ?? 0;
    l += params.textWeight * (t - params.textThreshold);
    logits[id] = l;
  }
  if (logits.isEmpty) {
    return RecognitionResult(
      status: RecognitionStatus.none,
      readName: readName,
      readSize: readSize,
    );
  }

  // Softmax with a "none of these" option at logit 0.
  final top = logits.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final shift = math.max(0.0, top.first.value);
  var z = math.exp(-shift);
  for (final e in top) {
    z += math.exp(e.value - shift);
  }
  final matches = <ProductMatch>[
    for (final e in top.take(limit))
      ProductMatch(productId: e.key, confidence: math.exp(e.value - shift) / z),
  ].where((m) => m.confidence >= 0.05).toList();

  final status = matches.isEmpty
      ? RecognitionStatus.none
      : (matches.length == 1 || matches[0].confidence - matches[1].confidence >= 0.15)
      ? RecognitionStatus.match
      : RecognitionStatus.multiple;
  return RecognitionResult(
    status: status,
    matches: matches,
    readName: readName,
    readSize: readSize,
  );
}
