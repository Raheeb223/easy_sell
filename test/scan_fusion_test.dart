import 'package:ai_shopkeeper/features/scan/domain/recognition_result.dart';
import 'package:ai_shopkeeper/features/scan/domain/scan_decision.dart';
import 'package:ai_shopkeeper/features/scan/domain/scan_fusion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ids = [for (var i = 0; i < 200; i++) 'p$i'];

  /// A 200-product shop where every product is taught and the scan looks
  /// like the typical unrelated product (~0.45, the RP2K median).
  Map<String, double> photos(Map<String, double> overrides) =>
      {for (final id in ids) id: 0.45, ...overrides};

  group('fuseScan', () {
    test('a typical photo match with no label text sells it', () {
      // Median right-product similarity on grocery photos is 0.75.
      final r = fuseScan(productIds: ids, photo: photos({'p7': 0.75}), text: const {});
      expect(decideScanAction(r).action, ScanAction.autoSell);
      expect(r.matches.first.productId, 'p7');
    });

    test('label text that names no product does not sink the photo match', () {
      // ML Kit cannot read Bangla: the label reads as text matching nothing.
      final r = fuseScan(
        productIds: ids,
        photo: photos({'p7': 0.75}),
        text: const {'p3': 0.2},
      );
      expect(decideScanAction(r).action, ScanAction.autoSell);
      expect(r.matches.first.productId, 'p7');
    });

    test('a weaker photo match lands in the chooser, not nowhere', () {
      // RP2K median right-product similarity is 0.62.
      final r = fuseScan(productIds: ids, photo: photos({'p7': 0.62}), text: const {});
      final d = decideScanAction(r);
      expect(d.action, isNot(ScanAction.noMatch));
      expect(d.matches.first.productId, 'p7');
    });

    test('nothing taught and nothing read -> none', () {
      final r = fuseScan(productIds: ids, photo: const {}, text: const {});
      expect(r.status, RecognitionStatus.none);
    });

    test('an untaught product is found by its label', () {
      final r = fuseScan(
        productIds: ids,
        photo: {for (final id in ids.take(20)) id: 0.45},
        text: const {'p150': 1.0},
      );
      expect(r.matches.first.productId, 'p150');
      expect(decideScanAction(r).action, isNot(ScanAction.noMatch));
    });

    test('with no photos taught, the label alone decides', () {
      final r = fuseScan(
        productIds: ids,
        photo: const {},
        text: const {'p4': 1.0, 'p5': 0.6},
      );
      expect(decideScanAction(r).action, ScanAction.autoSell);
      expect(r.matches.first.productId, 'p4');
    });
  });
}
