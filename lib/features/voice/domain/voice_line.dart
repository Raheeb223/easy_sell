import 'voice_decision.dart';
import 'voice_parse_result.dart';

/// One row in the review sheet: what was heard, how many, and which product it
/// resolves to. Immutable -- edits return a new instance.
class VoiceLine {
  VoiceLine({
    required this.heard,
    required this.quantity,
    required this.quantityAssumed,
    required this.status,
    required List<VoiceMatch> choices,
    this.chosenProductId,
    this.phrase,
  }) : choices = List.unmodifiable(choices);

  /// The product words alone; taught as an alias when the shopkeeper picks
  /// the product themselves.
  final String? phrase;

  final String heard;
  final double quantity;

  /// True when no count was spoken and we defaulted to 1; the UI highlights it.
  final bool quantityAssumed;

  final VoiceLineStatus status;

  /// Candidates to offer when the user must choose. Unmodifiable to prevent
  /// external mutation from corrupting sibling lines.
  final List<VoiceMatch> choices;

  /// The product this line will add to the cart. Null until settled.
  final String? chosenProductId;

  /// A line may only reach the cart once a real product is attached.
  bool get isSettled => chosenProductId != null;

  VoiceLine chooseProduct(String productId) => VoiceLine(
    heard: heard,
    quantity: quantity,
    quantityAssumed: quantityAssumed,
    status: status,
    choices: choices,
    chosenProductId: productId,
    phrase: phrase,
  );

  VoiceLine withQuantity(double newQuantity) => VoiceLine(
    heard: heard,
    quantity: newQuantity,
    // A human just supplied this number, so it is no longer assumed.
    quantityAssumed: false,
    status: status,
    choices: choices,
    chosenProductId: chosenProductId,
    phrase: phrase,
  );
}

/// Turn a parsed result into reviewable lines, pre-choosing only clear winners.
List<VoiceLine> buildVoiceLines(
  VoiceParseResult result, {
  VoiceThresholds thresholds = const VoiceThresholds(),
}) => [
  for (final item in result.items)
    () {
      final d = decideVoiceLine(item.matches, thresholds: thresholds);
      return VoiceLine(
        heard: item.heard,
        quantity: item.quantity,
        quantityAssumed: item.quantityAssumed,
        status: d.status,
        choices: d.choices,
        // Only a clear winner is pre-filled. Ambiguous and notFound stay null
        // so the user is forced to settle them.
        chosenProductId: d.status == VoiceLineStatus.resolved
            ? d.choices.single.productId
            : null,
        phrase: item.phrase,
      );
    }(),
];

/// Drop a line the user gave up on (e.g. an item they don't stock).
List<VoiceLine> removeLineAt(List<VoiceLine> lines, int index) =>
    [...lines]..removeAt(index);

/// The gate: nothing reaches the cart until every line has a real product.
bool canAddToCart(List<VoiceLine> lines) =>
    lines.isNotEmpty && lines.every((l) => l.isSettled);
