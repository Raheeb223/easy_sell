import 'package:ai_shopkeeper/features/voice/data/offline_bangla_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineBanglaCapture.hotwordsOf', () {
    test('keeps Bangla-script names, "/"-separated', () {
      expect(
        OfflineBanglaCapture.hotwordsOf(['লাক্স সাবান', 'মিনিকেট চাল']),
        'লাক্স সাবান/মিনিকেট চাল',
      );
    });

    test('drops Latin-only names: the Bangla word pieces cannot spell them', () {
      expect(OfflineBanglaCapture.hotwordsOf(['Lux Soap', 'ডাল']), 'ডাল');
    });

    test('a "/" or newline inside a name cannot split it into two hotwords', () {
      expect(OfflineBanglaCapture.hotwordsOf(['তেল/ঘি\nমধু']), 'তেল ঘি মধু');
    });

    test('empty and overlong entries are skipped', () {
      expect(OfflineBanglaCapture.hotwordsOf(['  ', 'চ' * 41, 'চা']), 'চা');
    });
  });
}
