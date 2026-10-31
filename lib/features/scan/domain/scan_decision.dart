import 'recognition_result.dart';

/// What the UI should do after a recognition result comes back.
enum ScanAction { autoSell, chooseFromMatches, noMatch }

/// Tunable thresholds mapping model confidences to a UI action, calibrated
/// with ml/calibrate_fusion.py: at 0.20 the chooser holds the right product
/// for ~27% more scans than at 0.50 (one tap instead of a search).
class ScanThresholds {
  const ScanThresholds({
    this.strong = 0.80,
    this.margin = 0.15,
    this.ambiguous = 0.20,
    this.maxChoices = 5,
  });

  /// Top-1 must reach this confidence to auto-open the sell sheet…
  final double strong;

  /// …and lead the runner-up by at least this margin.
  final double margin;

  /// Any match at/above this can appear in the chooser.
  final double ambiguous;

  /// Cap on candidates shown in the "Did you mean?" chooser.
  final int maxChoices;
}

/// The action to take plus the matches it applies to.
class ScanDecision {
  const ScanDecision(this.action, this.matches);
  final ScanAction action;
  final List<ProductMatch> matches;
}

/// Pure decision: given a [RecognitionResult], decide the UI action and which
/// matches to act on. No I/O — fully unit-testable.
ScanDecision decideScanAction(
  RecognitionResult result, {
  ScanThresholds thresholds = const ScanThresholds(),
}) {
  final ranked = [...result.matches]
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  if (ranked.isEmpty) return const ScanDecision(ScanAction.noMatch, []);

  final top = ranked.first;
  final second = ranked.length > 1 ? ranked[1] : null;
  final leadsClearly =
      second == null || (top.confidence - second.confidence) >= thresholds.margin;

  if (top.confidence >= thresholds.strong && leadsClearly) {
    return ScanDecision(ScanAction.autoSell, [top]);
  }

  final ambiguous =
      ranked.where((m) => m.confidence >= thresholds.ambiguous).toList();
  if (ambiguous.isNotEmpty) {
    return ScanDecision(
      ScanAction.chooseFromMatches,
      ambiguous.take(thresholds.maxChoices).toList(),
    );
  }
  return const ScanDecision(ScanAction.noMatch, []);
}
