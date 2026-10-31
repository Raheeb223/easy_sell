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
/// [photoWeight] and [photoThreshold] are calibrated with
/// `ml/calibrate_fusion.py` (200-product shops, 3 taught photos each). With
/// the v2 model and no usable label text, RP2K shelf photos auto-sell the
/// right product 43% of the time (1.1% wrong) and put it in the chooser
/// another 28%; grocery photos 63% (0.5% wrong) + 27%.
class FusionParams {
  const FusionParams({
    this.photoWeight = 24,
    this.photoThreshold = 0.55,
    this.textWeight = 9,
    this.textThreshold = 0.55,
    this.untaughtSimilarity = 0.45,
  });

  final double photoWeight;
  final double photoThreshold;
  final double textWeight;
  final double textThreshold;

  /// What a product without taught photos counts as on the photo side, when
  /// its name matches the label: a perfect text match still makes it the
  /// likely answer. Untaught products the label does not name are left out.
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
  // Label text only counts when it named some product. ML Kit reads Latin
  // script only, so a Bangla label (or a photo with no text) reads as nothing
  // matching -- that must not count against every product.
  final useText = text.values.any((t) => t >= params.textThreshold);
  for (final id in productIds) {
    final t = text[id] ?? 0;
    final taught = photo.containsKey(id);
    // No evidence for it at all: leave it out rather than let hundreds of
    // untaught products dilute the real match's confidence.
    if (!(usePhoto && taught) && !(useText && t >= params.textThreshold)) continue;
    var l = 0.0;
    if (usePhoto) {
      final s = photo[id] ?? params.untaughtSimilarity;
      l += params.photoWeight * (s - params.photoThreshold);
    }
    if (useText) l += params.textWeight * (t - params.textThreshold);
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
