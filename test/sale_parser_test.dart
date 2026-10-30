// The on-device sale parser keeps the rules the Gemini `parse-sale` prompt
// stated (phone-only design §6), including the Bangla fraction words ported
// from parse-sale/quantity_words.ts.
import 'package:ai_shopkeeper/core/matching/product_matcher.dart';
import 'package:ai_shopkeeper/features/voice/domain/sale_parser.dart';
import 'package:ai_shopkeeper/features/voice/domain/voice_parse_result.dart';
import 'package:flutter_test/flutter_test.dart';

const _products = [
  ParserProduct(id: 'pepsi500', name: 'Pepsi', variant: '500ml'),
  ParserProduct(id: 'pepsi1l', name: 'Pepsi', variant: '1 L'),
  ParserProduct(id: 'chips', name: 'Potato Chips', brand: 'Bombay'),
  ParserProduct(id: 'rice', name: 'Loose rice', unit: 'kg'),
  ParserProduct(id: 'sugar', name: 'Sugar', unit: 'kg'),
  ParserProduct(id: 'teer', name: 'Soybean Oil', brand: 'Teer', variant: '1 L'),
  ParserProduct(id: 'egg', name: 'Egg'),
];

VoiceParseResult parse(String text, {Map<String, double> recent = const {}}) =>
    SaleParser(products: _products, recentUnits: recent).parse(text);

String? top(VoiceItem item) =>
    item.matches.isEmpty ? null : item.matches.first.productId;

void main() {
  group('quantity and size', () {
    test('"2 pepsi 1 litre": size picks the product, count stays 2', () {
      final r = parse('2 pepsi 1 litre');
      expect(r.items, hasLength(1));
      expect(top(r.items.single), 'pepsi1l');
      expect(r.items.single.matches.first.confidence, greaterThan(0.8));
      expect(r.items.single.quantity, 2);
      expect(r.items.single.quantityAssumed, isFalse);
    });

    test('"pepsi" alone does not guess between sizes', () {
      final item = parse('pepsi').items.single;
      expect(item.matches.take(2).map((m) => m.productId).toSet(), {
        'pepsi500',
        'pepsi1l',
      });
      expect(
        (item.matches[0].confidence - item.matches[1].confidence).abs(),
        lessThan(0.15),
      );
      expect(item.quantityAssumed, isTrue);
      expect(item.quantity, 1);
    });

    test('a loose product sells the spoken amount, in its own unit', () {
      final item = parse('আড়াই কেজি চাল').items.single;
      expect(top(item), 'rice');
      expect(item.quantity, 2.5);
      final grams = parse('500 gram chini').items.single;
      expect(top(grams), 'sugar');
      expect(grams.quantity, 0.5);
    });
  });

  group('Bangla numbers', () {
    test('fraction words are exact', () {
      expect(parse('দেড় কেজি চিনি').items.single.quantity, 1.5);
      expect(parse('সাড়ে তিন কেজি চাল').items.single.quantity, 3.5);
      expect(parse('পৌনে চার কেজি চাল').items.single.quantity, 3.75);
      expect(parse('soya dui kg chal').items.single.quantity, 2.25);
      expect(parse('adha kg chini').items.single.quantity, 0.5);
    });

    test('classifiers and Bangla digits', () {
      expect(parse('দুইটা ডিম').items.single.quantity, 2);
      expect(parse('৩টা ডিম').items.single.quantity, 3);
      expect(parse('ek hali dim').items.single.quantity, 4);
      expect(parse('1 dozen egg').items.single.quantity, 12);
    });
  });

  group('several items', () {
    test('split by connectors and by a new quantity', () {
      final r = parse('2 pepsi 500ml and 3 chips');
      expect(r.items, hasLength(2));
      expect(top(r.items[0]), 'pepsi500');
      expect(r.items[0].quantity, 2);
      expect(top(r.items[1]), 'chips');
      expect(r.items[1].quantity, 3);
      final bn = parse('দুইটা ডিম আর এক কেজি চিনি');
      expect(bn.items.map(top), ['egg', 'sugar']);
    });

    test('trailing quantity attaches to its own item', () {
      final r = parse('chips 2 egg 6');
      expect(r.items.map((i) => (top(i), i.quantity)), [
        ('chips', 2.0),
        ('egg', 6.0),
      ]);
    });
  });

  group('matching across scripts and spellings', () {
    test('Bangla words find English names', () {
      expect(top(parse('তেল').items.single), 'teer');
      expect(top(parse('টির সয়াবিন তেল').items.single), 'teer');
      expect(top(parse('পেপসি ৫০০ মিলি').items.single), 'pepsi500');
    });

    test('a taught alias wins outright', () {
      final parser = SaleParser(
        products: [
          ..._products.where((p) => p.id != 'chips'),
          const ParserProduct(
            id: 'chips',
            name: 'Potato Chips',
            brand: 'Bombay',
            aliases: ['মজার প্যাকেট'],
          ),
        ],
      );
      final item = parser.parse('মজার প্যাকেট').items.single;
      expect(top(item), 'chips');
      expect(item.matches.first.confidence, greaterThan(0.8));
    });

    test('nothing sale-like gives no confident line', () {
      final r = parse('hello how are you');
      for (final it in r.items) {
        expect(it.matches.where((m) => m.confidence >= 0.5), isEmpty);
      }
    });
  });

  test('recent sales break a real tie, never a spoken size', () {
    final tie = parse('pepsi', recent: {'pepsi1l': 50, 'pepsi500': 2});
    expect(top(tie.items.single), 'pepsi1l');
    expect(tie.items.single.matches.first.confidence, greaterThan(0.8));
    final spoken = parse('pepsi 500ml', recent: {'pepsi1l': 50});
    expect(top(spoken.items.single), 'pepsi500');
  });

  group('matcher', () {
    test('OCR typos and sizes on a pack', () {
      final m = ProductMatcher([
        MatchTarget.of(id: 'a', name: 'Pepsi', variant: '500ml'),
        MatchTarget.of(id: 'b', name: 'Pepsi', variant: '1 L'),
        MatchTarget.of(id: 'c', name: 'Coca-Cola', variant: '250ml'),
      ]);
      final r = m.rank('PEPSl\nNet Vol 1 Ltr\nNEW TASTE');
      expect(r.first.id, 'b');
      expect(r.first.score, greaterThan(r[1].score + 0.2));
    });

    test('sizes normalise', () {
      expect(QueryText.parse('1 ltr').sizes, QueryText.parse('1000 ml').sizes);
      expect(QueryText.parse('1.5kg').sizes, QueryText.parse('1500 g').sizes);
      expect(QueryText.findSize('Teer oil 2 LTR pack'), '2 ltr');
    });
  });
}
