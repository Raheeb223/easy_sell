// A pack is read by two ML Kit engines (English, Bangla); the scan gets one
// reading with each line once.
import 'dart:ui';

import 'package:ai_shopkeeper/core/matching/product_matcher.dart';
import 'package:ai_shopkeeper/features/scan/data/label_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

TextLine line(String text, double height) => TextLine(
  text: text,
  elements: const [],
  boundingBox: Rect.fromLTWH(0, 0, 100, height),
  recognizedLanguages: const [],
  cornerPoints: const [],
  confidence: null,
  angle: null,
);

void main() {
  test('keeps English lines and adds the Bangla ones', () {
    final r = mergeLabelLines(
      [line('PRAN', 40), line('Mango Juice 250ml', 12)],
      [line('প্রাণ', 60), line('PRAN', 40), line('ম্যাংগো জুস', 20)],
    );
    expect(r.text.split('\n'), [
      'PRAN',
      'Mango Juice 250ml',
      'প্রাণ',
      'ম্যাংগো জুস',
    ]);
  });

  test('the headline is the tallest line in either script', () {
    final r = mergeLabelLines(
      [line('PRAN', 40)],
      [line('প্রাণ', 60)],
    );
    expect(r.headline, 'প্রাণ');
  });

  test('a Bangla-only pack still reads', () {
    final r = mergeLabelLines(const [], [line('রাঁধুনী হলুদ গুঁড়া', 30)]);
    expect(r.text, 'রাঁধুনী হলুদ গুঁড়া');
    expect(r.headline, 'রাঁধুনী হলুদ গুঁড়া');
  });

  test('nothing read gives an empty reading', () {
    final r = mergeLabelLines(const [], const []);
    expect(r.text, isEmpty);
    expect(r.headline, isNull);
  });

  group('a Bangla label names the product', () {
    final matcher = ProductMatcher([
      MatchTarget.of(id: 'juice', name: 'Pran Mango Juice'),
      MatchTarget.of(id: 'haldi', name: 'রাঁধুনী হলুদ গুঁড়া'),
      MatchTarget.of(id: 'oil', name: 'Teer Soybean Oil', variant: '1 litre'),
      MatchTarget.of(id: 'soap', name: 'Lux Soap'),
    ]);
    String? best(String text) {
      final r = matcher.rank(text);
      return r.isEmpty || r.first.score < 0.55 ? null : r.first.id;
    }

    test('Bangla pack, English product name', () {
      expect(best('প্রাণ\nম্যাংগো জুস'), 'juice');
    });
    test('Bangla pack, Bangla product name', () {
      expect(best('রাঁধুনী\nহলুদ গুঁড়া\n২০০ গ্রাম'), 'haldi');
    });
    test('English pack, Bangla product name', () {
      expect(best('RADHUNI\nTurmeric Powder'), 'haldi');
    });
    test('mixed pack', () {
      expect(best('তীর\nTEER\nSoybean Oil'), 'oil');
    });
  });
}
