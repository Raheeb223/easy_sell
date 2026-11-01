// A product saved in one language is found from a cover or pack written in
// the other: the same thing, not the same sound (`পদার্থবিজ্ঞান` is Physics).
import 'package:ai_shopkeeper/core/matching/product_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final matcher = ProductMatcher([
    MatchTarget.of(id: 'physics', name: 'Physics'),
    MatchTarget.of(id: 'chemistry', name: 'Chemistry'),
    MatchTarget.of(id: 'math', name: 'Mathematics'),
    MatchTarget.of(id: 'biology', name: 'Biology'),
    MatchTarget.of(id: 'english', name: 'English Grammar'),
    MatchTarget.of(id: 'book', name: 'Story Book'),
    MatchTarget.of(id: 'pen', name: 'Matador Pen'),
    MatchTarget.of(id: 'geo', name: 'ভূগোল গাইড'),
  ]);

  /// What a scan of [label] settles on (same 0.55 bar as the scan fusion).
  String? best(String label) {
    final r = matcher.rank(label);
    return r.isEmpty || r.first.score < 0.55 ? null : r.first.id;
  }

  test('a Bangla cover names the English-named book', () {
    expect(best('উচ্চ মাধ্যমিক\nপদার্থবিজ্ঞান\nপ্রথম পত্র'), 'physics');
    expect(best('রসায়ন'), 'chemistry');
    expect(best('গণিত'), 'math');
    expect(best('জীববিজ্ঞান'), 'biology');
  });

  test('the compound read as two words still means physics', () {
    expect(best('পদার্থ বিজ্ঞান'), 'physics');
  });

  test('a case ending does not hide the word', () {
    expect(best('পদার্থবিজ্ঞানের মূলনীতি'), 'physics');
  });

  test('an English cover names the Bangla-named book', () {
    expect(best('SSC Geography Guide'), 'geo');
  });

  test('রসায়ন is chemistry whichever way its য় is encoded', () {
    expect(best('রসায়ন'), 'chemistry'); // য় as one letter
    expect(best('রসায়ন'), 'chemistry'); // য + nukta
  });

  test('a phrase in both languages still finds the product', () {
    expect(best('ইংরেজি গ্রামার'), 'english');
    expect(best('ম্যাটাডোর কলম'), 'pen');
  });

  test('meaning does not swamp the brand: an unrelated cover finds nothing', () {
    expect(best('ইতিহাস'), isNull);
  });
}
