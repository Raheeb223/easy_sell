// The parsed outcome of a `parse-sale` request. Plain Dart (no codegen) so the
// JSON handling is small, explicit, and directly unit-testable -- same choice as
// the vision scan's RecognitionResult.

/// One candidate product the model matched, by the shop's own product id.
class VoiceMatch {
  const VoiceMatch({required this.productId, required this.confidence});

  final String productId;
  final double confidence;

  factory VoiceMatch.fromJson(Map<String, dynamic> json) {
    final productId = json['product_id'];
    if (productId is! String) {
      throw FormatException('product_id must be a String');
    }
    final confidence = json['confidence'];
    return VoiceMatch(
      productId: productId,
      confidence: confidence is num ? confidence.toDouble() : 0,
    );
  }
}

/// One spoken item: what was heard, how many, and which products it might be.
class VoiceItem {
  const VoiceItem({
    required this.heard,
    required this.quantity,
    required this.quantityAssumed,
    this.unitHeard,
    this.matches = const <VoiceMatch>[],
    this.phrase,
  });

  /// The words that named the product, without the quantity ("pepsi" from
  /// "2 ta pepsi"). What a correction teaches as an alias.
  final String? phrase;

  /// The fragment of speech this line came from, e.g. "pepsi 1 litre". Size
  /// words live HERE (they identify the product); counts live in [quantity].
  final String heard;

  /// How many units. Never carries a size -- see [heard].
  final double quantity;

  /// True when the speaker gave no count and we defaulted to 1. The review UI
  /// highlights these so an assumed number is never mistaken for a heard one.
  final bool quantityAssumed;

  /// A spoken count word ("piece", "packet", "টা"), when present. Advisory only.
  final String? unitHeard;

  /// Ranked candidates, highest confidence first.
  final List<VoiceMatch> matches;

  factory VoiceItem.fromJson(Map<String, dynamic> json) {
    final rawQty = json['quantity'];
    final qty = rawQty is num ? rawQty.toDouble() : null;
    final valid = qty != null && qty > 0;

    final rawMatches = json['matches'];
    final matchesList = rawMatches is List ? rawMatches : [];

    final heard = json['heard'];
    final heardStr = heard is String ? heard : '';

    final unitHeard = json['unit_heard'];
    final unitHeardStr = unitHeard is String ? unitHeard : null;

    final matches = <VoiceMatch>[];
    for (final m in matchesList) {
      if (m is Map) {
        try {
          matches.add(VoiceMatch.fromJson(Map<String, dynamic>.from(m)));
        } catch (_) {
          // Skip invalid match
        }
      }
    }

    return VoiceItem(
      heard: heardStr,
      quantity: valid ? qty : 1,
      quantityAssumed: !valid,
      unitHeard: unitHeardStr,
      matches: matches,
    );
  }

  /// Returns a copy with [matches] replaced, everything else unchanged. Used
  /// by [VoiceParseResult.resolveIds] to swap indices for real product ids.
  VoiceItem copyWithMatches(List<VoiceMatch> matches) => VoiceItem(
    heard: heard,
    quantity: quantity,
    quantityAssumed: quantityAssumed,
    unitHeard: unitHeard,
    matches: matches,
    phrase: phrase,
  );
}

/// Normalized result returned by the `parse-sale` Edge Function.
class VoiceParseResult {
  const VoiceParseResult({this.heardText, this.items = const <VoiceItem>[]});

  /// The full transcript, shown to the user so a mishear is obvious.
  final String? heardText;
  final List<VoiceItem> items;

  factory VoiceParseResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemsList = rawItems is List ? rawItems : [];

    final heardText = json['heard_text'];
    final heardTextStr = heardText is String ? heardText : null;

    return VoiceParseResult(
      heardText: heardTextStr,
      items: [
        for (final i in itemsList)
          if (i is Map) VoiceItem.fromJson(Map<String, dynamic>.from(i)),
      ],
    );
  }

  /// Translates every match's identifier through [resolve], dropping any the
  /// resolver rejects. Called immediately after parsing so nothing downstream
  /// -- the review sheet, `chosenProductId`, the cart -- ever sees an index.
  VoiceParseResult resolveIds(String? Function(String) resolve) =>
      VoiceParseResult(
        heardText: heardText,
        items: [
          for (final it in items)
            it.copyWithMatches([
              for (final m in it.matches)
                if (resolve(m.productId) case final String id)
                  VoiceMatch(productId: id, confidence: m.confidence),
            ]),
        ],
      );
}
