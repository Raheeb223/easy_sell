import 'dart:math' as math;

import '../../../core/matching/product_matcher.dart';
import 'voice_parse_result.dart';

/// Turns a spoken sale sentence into line items, on the phone (design §6).
/// Replaces the Gemini `parse-sale` function and keeps its rules:
///
///   * quantity and size are different things: for a packaged product
///     (`pcs`) a size (`1 litre`) picks WHICH product and the count stays the
///     count; for a loose product (`kg`, `g`, `litre`, `ml`) the spoken amount
///     IS the quantity, converted to the product's unit;
///   * Bangla fractions are exact: আধা 0.5, দেড় 1.5, আড়াই 2.5, and
///     সোয়া/সাড়ে/পৌনে N = N+0.25 / N+0.5 / N-0.25 (ported from
///     `parse-sale/quantity_words.ts`, with its tests);
///   * no count spoken -> quantity 1, flagged as assumed;
///   * when the words do not tell two products apart, both come back with
///     similar confidence so the review sheet asks; recent sales only break
///     a real tie, never override a spoken size or brand.
class SaleParser {
  SaleParser({
    required List<ParserProduct> products,
    Map<String, double> recentUnits = const {},
  }) : _products = {for (final p in products) p.id: p},
       _recent = recentUnits,
       _matcher = ProductMatcher([
         for (final p in products)
           MatchTarget.of(
             id: p.id,
             name: p.name,
             brand: p.brand,
             variant: p.variant,
             extra: p.aliases,
           ),
       ]),
       _aliases = {
         for (final p in products)
           for (final a in p.aliases) aliasKey(a): p.id,
       };

  final Map<String, ParserProduct> _products;
  final Map<String, double> _recent;
  final ProductMatcher _matcher;
  final Map<String, String> _aliases;

  /// Parses [transcript]. With [alternatives] (the recogniser's other
  /// guesses), the reading that matches the shop's products best wins.
  VoiceParseResult parse(String transcript, {List<String> alternatives = const []}) {
    VoiceParseResult? best;
    var bestScore = -1.0;
    for (final text in {transcript, ...alternatives}) {
      if (text.trim().isEmpty) continue;
      final r = _parseOne(text);
      // Score: matched confidence per item, lightly favouring the first
      // (most likely) transcript.
      var s = 0.0;
      for (final it in r.items) {
        s += it.matches.isEmpty ? 0 : it.matches.first.confidence;
      }
      if (text == transcript) s += 0.05;
      if (s > bestScore) {
        bestScore = s;
        best = r;
      }
    }
    return best ?? VoiceParseResult(heardText: transcript);
  }

  VoiceParseResult _parseOne(String transcript) {
    final items = <VoiceItem>[];
    final pieces = splitSaleItems(transcript);
    for (final piece in pieces) {
      final item = _item(piece, soleItem: pieces.length == 1);
      if (item != null) items.add(item);
    }
    return VoiceParseResult(heardText: transcript, items: items);
  }

  VoiceItem? _item(SpokenItem piece, {required bool soleItem}) {
    final words = piece.words.join(' ');
    if (words.trim().isEmpty) return null;
    final query = [words, ?piece.measure?.text].join(' ');

    // Learned alias said exactly: the shopkeeper taught us this phrase.
    final aliasHit = _aliases[normalizePhrase(words)];
    final ranked = _matcher.rank(query, mode: MatchMode.phrase);
    var matches = _confidences(ranked, aliasHit: aliasHit);
    if (piece.measure == null) matches = _tieBreakByRecentSales(matches);

    final top = matches.isEmpty ? null : _products[matches.first.productId];
    final (qty, assumed) = _quantityFor(piece, top);
    return VoiceItem(
      heard: piece.heard,
      quantity: qty,
      quantityAssumed: assumed,
      unitHeard: piece.measure?.unit ?? piece.countUnit,
      matches: matches,
      phrase: words,
    );
  }

  /// Softmax over products against a "none of these" option, so a vague
  /// phrase leaves every product under the review sheet's 0.50 floor.
  List<VoiceMatch> _confidences(List<TextScore> ranked, {String? aliasHit}) {
    const k = 11.0, threshold = 0.52;
    final logits = <String, double>{
      for (final s in ranked.take(8)) s.id: k * (s.score - threshold),
    };
    if (aliasHit != null) {
      logits[aliasHit] = math.max(logits[aliasHit] ?? 0, 6);
    }
    if (logits.isEmpty) return const [];
    final maxL = math.max(0.0, logits.values.reduce(math.max));
    var z = math.exp(-maxL);
    for (final l in logits.values) {
      z += math.exp(l - maxL);
    }
    final out = [
      for (final e in logits.entries)
        VoiceMatch(productId: e.key, confidence: math.exp(e.value - maxL) / z),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));
    return out.where((m) => m.confidence >= 0.05).take(5).toList();
  }

  /// Two products the words cannot tell apart: if one sells at least 5x the
  /// other, the shopkeeper almost certainly meant it -- give it a decisive
  /// lead; otherwise leave the tie for the sheet to ask.
  List<VoiceMatch> _tieBreakByRecentSales(List<VoiceMatch> m) {
    if (m.length < 2) return m;
    final a = m[0], b = m[1];
    if (a.confidence - b.confidence >= 0.15 || a.confidence < 0.3) return m;
    final ra = _recent[a.productId] ?? 0, rb = _recent[b.productId] ?? 0;
    VoiceMatch? win, lose;
    if (ra >= 5 * math.max(1, rb) && ra > 0) {
      (win, lose) = (a, b);
    } else if (rb >= 5 * math.max(1, ra) && rb > 0) {
      (win, lose) = (b, a);
    }
    if (win == null || lose == null) return m;
    return [
      VoiceMatch(productId: win.productId, confidence: 0.88),
      VoiceMatch(productId: lose.productId, confidence: 0.45),
      ...m.skip(2),
    ];
  }

  (double, bool) _quantityFor(SpokenItem piece, ParserProduct? product) {
    final unit = product?.unit ?? 'pcs';
    final measure = piece.measure;
    if (unit != 'pcs' && measure != null) {
      final v = convertAmount(measure.amount, measure.unit, unit);
      if (v != null && v > 0) return (v, false);
    }
    if (piece.count != null && piece.count! > 0) return (piece.count!, false);
    return (1, true);
  }
}

/// What the parser needs to know about a product.
class ParserProduct {
  const ParserProduct({
    required this.id,
    required this.name,
    this.brand,
    this.variant,
    this.unit = 'pcs',
    this.aliases = const [],
  });

  final String id;
  final String name;
  final String? brand;
  final String? variant;

  /// `pcs` | `kg` | `g` | `litre` | `ml`.
  final String unit;

  /// Words the shopkeeper taught for this product (voice corrections).
  final List<String> aliases;
}

/// An amount said with a weight/volume unit.
class Measure {
  const Measure(this.amount, this.unit, this.text);
  final double amount;

  /// `kg` | `g` | `litre` | `ml`.
  final String unit;

  /// As spoken, e.g. `2.5 kg`, so the size can also pick a product.
  final String text;
}

/// One item of a spoken sale, before product matching.
class SpokenItem {
  SpokenItem();
  final words = <String>[];
  final heardParts = <String>[];

  /// A quantity came after the product words ("pepsi 2"): the next word
  /// starts a new item.
  bool quantityClosed = false;
  double? count;
  String? countUnit;
  Measure? measure;

  String get heard => heardParts.join(' ');
  bool get isEmpty => words.isEmpty && count == null && measure == null;
}

/// Converts an amount between kg/g and litre/ml; null across dimensions.
double? convertAmount(double amount, String from, String to) {
  if (from == to) return amount;
  return switch ((from, to)) {
    ('kg', 'g') => amount * 1000,
    ('g', 'kg') => amount / 1000,
    ('litre', 'ml') => amount * 1000,
    ('ml', 'litre') => amount / 1000,
    _ => null,
  };
}

/// An alias as the parser will meet it: only the product words, the way
/// [splitSaleItems] extracts them from speech (no counts, units or fillers).
String aliasKey(String phrase) {
  final items = splitSaleItems(phrase);
  final words = [for (final it in items) ...it.words].join(' ');
  return normalizePhrase(words.isEmpty ? phrase : words);
}

String normalizePhrase(String s) => normalizeDigits(s.toLowerCase())
    .replaceAll(RegExp(r'[^a-z0-9ঀ-৿]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

// ---------------------------------------------------------------------------
// Quantity words (port of parse-sale/quantity_words.ts, extended).
// ---------------------------------------------------------------------------

const _standalone = <String, double>{
  'আধা': 0.5, 'আধ': 0.5, 'adha': 0.5, 'aadha': 0.5, 'adh': 0.5, 'half': 0.5,
  'haf': 0.5,
  'দেড়': 1.5, 'der': 1.5, 'derh': 1.5, 'dedh': 1.5, 'deed': 1.5, 'deur': 1.5,
  'আড়াই': 2.5, 'arai': 2.5, 'aarai': 2.5, 'adai': 2.5, 'aadai': 2.5,
  'arhai': 2.5,
};

const _prefix = <String, double>{
  'সোয়া': 0.25, 'shoya': 0.25, 'showa': 0.25, 'soya': 0.25, 'sawa': 0.25,
  'সাড়ে': 0.5, 'sare': 0.5, 'share': 0.5, 'saare': 0.5, 'shaare': 0.5,
  'sadhe': 0.5,
  'পৌনে': -0.25, 'poune': -0.25, 'pone': -0.25, 'powne': -0.25,
  'pouney': -0.25,
};

const _cardinals = <String, double>{
  'এক': 1, 'ek': 1, 'one': 1, 'a': 1, 'an': 1,
  'দুই': 2, 'দু': 2, 'dui': 2, 'du': 2, 'two': 2,
  'তিন': 3, 'tin': 3, 'three': 3,
  'চার': 4, 'char': 4, 'car': 4, 'four': 4,
  'পাঁচ': 5, 'pach': 5, 'panch': 5, 'paanch': 5, 'five': 5,
  'ছয়': 6, 'choy': 6, 'chhoy': 6, 'six': 6,
  'সাত': 7, 'sat': 7, 'saat': 7, 'seven': 7,
  'আট': 8, 'aat': 8, 'eight': 8,
  'নয়': 9, 'noy': 9, 'noi': 9, 'nine': 9,
  'দশ': 10, 'dosh': 10, 'dos': 10, 'ten': 10,
  'এগারো': 11, 'egaro': 11, 'eleven': 11,
  'বারো': 12, 'baro': 12, 'twelve': 12,
  'তেরো': 13, 'tero': 13, 'thirteen': 13,
  'চোদ্দ': 14, 'চৌদ্দ': 14, 'choddo': 14, 'fourteen': 14,
  'পনেরো': 15, 'ponero': 15, 'fifteen': 15,
  'ষোল': 16, 'sixteen': 16,
  'সতেরো': 17, 'seventeen': 17,
  'আঠারো': 18, 'eighteen': 18,
  'উনিশ': 19, 'nineteen': 19,
  'বিশ': 20, 'কুড়ি': 20, 'bish': 20, 'kuri': 20, 'twenty': 20,
  'পঁচিশ': 25, 'twenty-five': 25,
  'ত্রিশ': 30, 'তিরিশ': 30, 'thirty': 30,
  'চল্লিশ': 40, 'forty': 40,
  'পঞ্চাশ': 50, 'fifty': 50,
  'একশ': 100, 'একশো': 100, 'hundred': 100,
};

/// Count classifiers glued to or after a number: দুইটা, ২টি, ekta, 3 pcs.
const _classifiers = ['টা', 'টি', 'টো', 'টে', 'খানা', 'খান', 'ta', 'ti', 'to', 'khana'];

const _countUnits = <String, double>{
  'piece': 1, 'pieces': 1, 'pcs': 1, 'pc': 1, 'pis': 1, 'পিস': 1,
  'packet': 1, 'packets': 1, 'pack': 1, 'প্যাকেট': 1, 'paket': 1,
  'bottle': 1, 'bottles': 1, 'বোতল': 1, 'botol': 1,
  'can': 1, 'cans': 1, 'ক্যান': 1, 'box': 1, 'বক্স': 1,
  'ta': 1, 'ti': 1, 'টা': 1, 'টি': 1,
  'hali': 4, 'হালি': 4,
  'dozen': 12, 'ডজন': 12, 'dojon': 12,
};

const _measureUnits = <String, String>{
  'kg': 'kg', 'kgs': 'kg', 'kilo': 'kg', 'kilos': 'kg', 'কেজি': 'kg',
  'কিলো': 'kg', 'keji': 'kg', 'kezi': 'kg',
  'g': 'g', 'gm': 'g', 'gms': 'g', 'gram': 'g', 'grams': 'g', 'গ্রাম': 'g',
  'l': 'litre', 'ltr': 'litre', 'litre': 'litre', 'liter': 'litre',
  'litres': 'litre', 'liters': 'litre', 'লিটার': 'litre', 'liter.': 'litre',
  'ml': 'ml', 'মিলি': 'ml', 'milli': 'ml', 'millilitre': 'ml',
};

const _connectors = {
  'and', 'plus', 'then', 'also', 'আর', 'এবং', 'ও', 'আরো', 'আরও', 'তারপর',
  'ar', 'aar', 'ebong', 'abar', 'আবার',
};

const _fillers = {
  'give', 'me', 'please', 'plz', 'want', 'need', 'sell', 'sold', 'of',
  'দাও', 'দিন', 'দেন', 'দে', 'চাই', 'লাগবে', 'দরকার', 'ভাই', 'আপা', 'আমাকে',
  'একটু', 'dao', 'din', 'den', 'chai', 'lagbe', 'dorkar', 'bhai', 'apa',
  'amake', 'ektu', 'hobe', 'হবে', 'nibo', 'নিবো', 'নেব', 'the',
};

const _money = {'taka', 'takar', 'tk', 'টাকা', 'টাকার'};

/// A number word or digits, with any glued classifier removed.
({double value, bool counted})? _number(String token) {
  var t = token;
  var counted = false;
  for (final c in _classifiers) {
    if (t.length > c.length && t.endsWith(c)) {
      final stem = t.substring(0, t.length - c.length);
      if (_cardinalOf(stem) != null || _standalone.containsKey(stem)) {
        t = stem;
        counted = true;
        break;
      }
    }
  }
  final v = _cardinalOf(t) ?? _standalone[t];
  return v == null ? null : (value: v, counted: counted);
}

double? _cardinalOf(String t) {
  final w = _cardinals[t];
  if (w != null) return w;
  final d = normalizeDigits(t).replaceAll(',', '.');
  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(d)) return double.parse(d);
  return null;
}

List<String> _tokenize(String text) => normalizeDigits(text.toLowerCase())
    .replaceAll(RegExp('[‌‍]'), '')
    // One spelling for the nukta letters (য় ড় ঢ়), whichever the recogniser used.
    .replaceAll('য়', 'য়')
    .replaceAll('ড়', 'ড়')
    .replaceAll('ঢ়', 'ঢ়')
    // "2kg", "500ml", "২কেজি": split digits from a glued unit.
    .replaceAllMapped(
      RegExp(r'(\d)([a-zঀ-৿])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    )
    .split(RegExp(r'[^a-z0-9.ঀ-৿-]+|(?<!\d)\.|\.(?!\d)'))
    .where((t) => t.isNotEmpty && t != '-')
    .toList();

/// Splits a sentence into items. A new item starts at a connector word, or
/// at a quantity once the current item already has its words and that kind
/// of quantity ("2 pepsi 3 chips" -> pepsi x2, chips x3; "pepsi 2" ->
/// pepsi x2).
List<SpokenItem> splitSaleItems(String text) {
  final tokens = _tokenize(text);
  final items = <SpokenItem>[];
  var cur = SpokenItem();

  void push() {
    if (!cur.isEmpty && cur.words.isNotEmpty) items.add(cur);
    cur = SpokenItem();
  }

  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (_connectors.contains(t)) {
      if (cur.words.isNotEmpty) push();
      continue;
    }
    if (_fillers.contains(t)) continue;

    // Fraction modifier + number: সাড়ে তিন = 3.5.
    double? value;
    var used = 1;
    var counted = false;
    final offset = _prefix[t];
    if (offset != null && i + 1 < tokens.length) {
      final next = _number(tokens[i + 1]);
      if (next != null) {
        value = next.value + offset;
        counted = next.counted;
        used = 2;
      }
    }
    if (value == null) {
      final n = _number(t);
      // A lone "a"/"an" is a number only before a unit or product word.
      if (n != null && !((t == 'a' || t == 'an') && i + 1 >= tokens.length)) {
        value = n.value;
        counted = n.counted;
      }
    }

    if (value != null) {
      final spoken = tokens.sublist(i, i + used).join(' ');
      var j = i + used;
      // Money amount ("50 taka") is not a quantity: skip it.
      if (j < tokens.length && _money.contains(tokens[j])) {
        i = j;
        continue;
      }
      final unitTok = j < tokens.length ? tokens[j] : null;
      final measureUnit = unitTok == null ? null : _measureUnits[unitTok];
      final countMult = unitTok == null ? null : _countUnits[unitTok];
      if (measureUnit != null) {
        if (cur.measure != null && cur.words.isNotEmpty) push();
        cur.measure = Measure(value, measureUnit, '$spoken $unitTok');
        if (cur.words.isNotEmpty) cur.quantityClosed = true;
        cur.heardParts.add('$spoken $unitTok');
        i = j;
        continue;
      }
      if (countMult != null) {
        value *= countMult;
        cur.countUnit = unitTok;
        j++;
      } else if (counted) {
        cur.countUnit = 'pcs';
      }
      if (cur.count != null && cur.words.isNotEmpty) push();
      cur.count = value;
      if (cur.words.isNotEmpty) cur.quantityClosed = true;
      cur.heardParts.add(
        countMult != null ? '$spoken $unitTok' : spoken,
      );
      i = j - 1;
      continue;
    }

    // A unit word on its own ("packet chips"): part of the phrase, not a word
    // to match on.
    if (_countUnits.containsKey(t) || _measureUnits.containsKey(t)) {
      cur.heardParts.add(t);
      continue;
    }
    if (cur.quantityClosed) push();
    cur.words.add(t);
    cur.heardParts.add(t);
  }
  push();
  return items;
}
