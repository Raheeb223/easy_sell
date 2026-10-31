import 'package:ai_shopkeeper/features/scan/domain/recognition_result.dart';
import 'package:ai_shopkeeper/features/scan/domain/scan_decision.dart';
import 'package:flutter_test/flutter_test.dart';

RecognitionResult _result(List<(String, double)> m, {RecognitionStatus s = RecognitionStatus.match}) =>
    RecognitionResult(
      status: s,
      matches: [for (final e in m) ProductMatch(productId: e.$1, confidence: e.$2)],
    );

void main() {
  group('decideScanAction', () {
    test('strong top-1 with clear margin -> autoSell', () {
      final d = decideScanAction(_result([('a', 0.92), ('b', 0.40)]));
      expect(d.action, ScanAction.autoSell);
      expect(d.matches.single.productId, 'a');
    });

    test('strong top-1 but close runner-up -> chooser', () {
      final d = decideScanAction(_result([('a', 0.90), ('b', 0.85)]));
      expect(d.action, ScanAction.chooseFromMatches);
      expect(d.matches.map((m) => m.productId), ['a', 'b']);
    });

    test('no strong match but some above ambiguous -> chooser', () {
      final d = decideScanAction(_result([('a', 0.60), ('b', 0.55), ('c', 0.10)]));
      expect(d.action, ScanAction.chooseFromMatches);
      expect(d.matches.map((m) => m.productId), ['a', 'b']);
    });

    test('all below ambiguous -> noMatch', () {
      final d = decideScanAction(_result([('a', 0.15)]));
      expect(d.action, ScanAction.noMatch);
      expect(d.matches, isEmpty);
    });

    test('empty matches -> noMatch', () {
      final d = decideScanAction(_result([], s: RecognitionStatus.none));
      expect(d.action, ScanAction.noMatch);
    });

    test('unsorted input is ranked before deciding', () {
      final d = decideScanAction(_result([('b', 0.40), ('a', 0.92)]));
      expect(d.action, ScanAction.autoSell);
      expect(d.matches.single.productId, 'a');
    });

    test('chooser caps at 5 candidates', () {
      final d = decideScanAction(_result([
        ('a', 0.60), ('b', 0.59), ('c', 0.58), ('d', 0.57), ('e', 0.56), ('f', 0.55),
      ]));
      expect(d.action, ScanAction.chooseFromMatches);
      expect(d.matches.length, 5);
    });
  });
}
