import 'dart:math' as math;

import 'bangla_translit.dart';
import 'grocery_lexicon.dart';

/// Finds which of the shop's products a piece of text means -- the words read
/// off a pack by ML Kit (scan) or a spoken phrase (voice). Replaces the
/// catalogue matching Gemini did server-side; runs on the phone in a few ms.
///
/// Tolerant of what each input gets wrong:
///   * OCR typos (`Pepsl`, `C0ke`): character-trigram similarity;
///   * sizes written any way (`1 L`, `1ltr`, `1000 ml`): one canonical form,
///     with a bonus when the size matches and a penalty when it conflicts --
///     this is what tells Pepsi 1L from Pepsi 500ml;
///   * Bangla speech for Latin names (`পেপসি` -> `pepsi`) and the reverse:
///     both sides compared in a phonetic Latin key;
///   * common words (`rice`, `oil`) count less than rare ones (`teer`), so a
///     brand name decides more than a category word.
class ProductMatcher {
  ProductMatcher(List<MatchTarget> targets) : _targets = targets {
    final df = <String, int>{};
    for (final t in _targets) {
      for (final tok in {...t.tokens.map((x) => x.key)}) {
        df[tok] = (df[tok] ?? 0) + 1;
      }
    }
    final n = math.max(1, _targets.length);
    _idf = {
      for (final e in df.entries) e.key: math.log(1 + n / e.value) + 0.5,
    };
  }

  final List<MatchTarget> _targets;
  late final Map<String, double> _idf;

  /// Every target scored against [text], best first; scores are 0..1.
  /// [mode] decides what must be explained: [MatchMode.label] asks how much
  /// of the PRODUCT's name appears in a long label text; [MatchMode.phrase]
  /// also asks how much of a short spoken phrase the product explains.
  List<TextScore> rank(String text, {MatchMode mode = MatchMode.label}) {
    final q = QueryText.parse(text);
    if (q.tokens.isEmpty && q.sizes.isEmpty) return const [];
    final out = <TextScore>[];
    for (final t in _targets) {
      final s = _score(t, q, mode);
      if (s > 0) out.add(TextScore(t.id, s));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  double _score(MatchTarget t, QueryText q, MatchMode mode) {
    if (t.tokens.isEmpty) return 0;
    // How much of the product's name the text contains (rare words weigh more).
    var got = 0.0, total = 0.0;
    for (final tok in t.tokens) {
      final w = (_idf[tok.key] ?? 1.0) * math.min(1.0, tok.key.length / 4);
      total += w;
      got += w * q.best(tok);
    }
    var score = total == 0 ? 0.0 : got / total;

    if (mode == MatchMode.phrase && q.tokens.isNotEmpty) {
      // A spoken phrase is short: its words should all be explained too.
      var qGot = 0.0;
      for (final qt in q.tokens) {
        var best = 0.0;
        for (final tok in t.tokens) {
          best = math.max(best, tokenSimilarity(qt, tok));
        }
        qGot += best;
      }
      final explained = qGot / q.tokens.length;
      score = 0.6 * score + 0.4 * explained;
    }

    // Size: decisive between variants of one product.
    if (t.sizes.isNotEmpty && q.sizes.isNotEmpty) {
      final same = t.sizes.any(q.sizes.contains);
      final sameDimension = t.sizes.any(
        (s) => q.sizes.any((qs) => qs.unit == s.unit),
      );
      if (same) {
        score = math.min(1.0, score + 0.15);
      } else if (sameDimension) {
        score *= 0.45;
      }
    }
    return score;
  }
}

enum MatchMode { label, phrase }

class TextScore {
  const TextScore(this.id, this.score);
  final String id;
  final double score;
}

/// One product as the matcher sees it.
class MatchTarget {
  MatchTarget._(this.id, this.tokens, this.sizes);

  /// [extra] are learned aliases (voice corrections).
  factory MatchTarget.of({
    required String id,
    required String name,
    String? brand,
    String? variant,
    List<String> extra = const [],
  }) {
    final text = [brand, name, variant, ...extra].whereType<String>().join(' ');
    final q = QueryText.parse(text);
    return MatchTarget._(id, q.tokens, q.sizes);
  }

  final String id;
  final List<Token> tokens;
  final Set<Size> sizes;
}

/// A word in both spellings: as written, and as a comparable key -- its
/// grocery concept when it has one (`চিনি`, `chini`, `sugar` -> `#sugar`),
/// else its phonetic Latin key.
class Token {
  Token(this.raw) : key = groceryConcepts[raw] ?? phoneticKey(raw);
  final String raw;
  final String key;

  @override
  bool operator ==(Object other) => other is Token && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// A size in one canonical unit: millilitres, grams or pieces.
class Size {
  const Size(this.amount, this.unit);
  final int amount;
  final String unit; // ml | g | pcs

  @override
  bool operator ==(Object other) =>
      other is Size && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);

  @override
  String toString() => '$amount$unit';
}

/// Text split into comparable words and sizes.
class QueryText {
  QueryText(this.tokens, this.sizes);

  final List<Token> tokens;
  final Set<Size> sizes;

  static final _sizeRe = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(ml|mls|millilitre|milliliter|ltr|litre|liter|lit|lt|l|kg|kgs|kilo|gm|gms|gram|grams|gr|g|pcs|pc|piece|pieces)\b',
  );

  static const _stop = {
    'new', 'fresh', 'net', 'wt', 'weight', 'vol', 'volume', 'contents', 'mrp',
    'tk', 'taka', 'bdt', 'price', 'pack', 'the', 'and', 'with', 'for', 'of',
    'best', 'before', 'mfg', 'exp', 'date', 'batch', 'made', 'in', 'by',
    'ingredients', 'tm', 'r', 'only', 'free', 'extra', 'offer',
  };

  factory QueryText.parse(String text) {
    var s = normalizeDigits(text.toLowerCase());
    final sizes = <Size>{};
    s = s.replaceAllMapped(_sizeRe, (m) {
      final size = _size(m.group(1)!, m.group(2)!);
      if (size != null) sizes.add(size);
      return ' ';
    });
    final words = s
        .split(RegExp(r'[^a-z0-9ঀ-৿]+'))
        .where((w) => w.length >= 2 && !_stop.contains(w))
        .where((w) => !RegExp(r'^\d+$').hasMatch(w))
        .toList();
    return QueryText([for (final w in words) Token(w)], sizes);
  }

  /// The first size written in [text] as it was written (`1 Ltr`), or null.
  static String? findSize(String text) =>
      _sizeRe.firstMatch(normalizeDigits(text.toLowerCase()))?.group(0)?.trim();

  static Size? _size(String number, String unit) {
    final v = double.tryParse(number.replaceAll(',', '.'));
    if (v == null || v <= 0) return null;
    return switch (unit) {
      'ml' || 'mls' || 'millilitre' || 'milliliter' => Size(v.round(), 'ml'),
      'ltr' || 'litre' || 'liter' || 'lit' || 'lt' || 'l' =>
        Size((v * 1000).round(), 'ml'),
      'kg' || 'kgs' || 'kilo' => Size((v * 1000).round(), 'g'),
      'gm' || 'gms' || 'gram' || 'grams' || 'gr' || 'g' => Size(v.round(), 'g'),
      _ => Size(v.round(), 'pcs'),
    };
  }

  /// How well some word of this text matches [t] (0..1).
  double best(Token t) {
    var b = 0.0;
    for (final q in tokens) {
      final s = tokenSimilarity(q, t);
      if (s > b) {
        b = s;
        if (b >= 1) break;
      }
    }
    return b;
  }
}

/// Similarity of two words: exact, prefix (an abbreviation like `cola` in
/// `colas`), or trigram overlap of their phonetic keys (typos, Bangla).
double tokenSimilarity(Token a, Token b) {
  if (a.key == b.key || a.raw == b.raw) return 1;
  final x = a.key, y = b.key;
  if (x.length >= 3 && y.length >= 3 && (x.startsWith(y) || y.startsWith(x))) {
    final ratio = math.min(x.length, y.length) / math.max(x.length, y.length);
    return 0.7 + 0.25 * ratio;
  }
  final t = trigramSimilarity(x, y);
  return t < 0.3 ? 0 : t;
}

/// Dice coefficient over character trigrams of the padded words.
double trigramSimilarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final ga = _grams(a), gb = _grams(b);
  var common = 0;
  final pool = Map<String, int>.from(gb);
  for (final e in ga.entries) {
    final n = pool[e.key];
    if (n != null) common += math.min(n, e.value);
  }
  final total =
      ga.values.fold<int>(0, (s, v) => s + v) +
      gb.values.fold<int>(0, (s, v) => s + v);
  return total == 0 ? 0 : 2 * common / total;
}

Map<String, int> _grams(String w) {
  final s = '  $w ';
  final out = <String, int>{};
  for (var i = 0; i + 3 <= s.length; i++) {
    final g = s.substring(i, i + 3);
    out[g] = (out[g] ?? 0) + 1;
  }
  return out;
}

/// A spelling-insensitive Latin key: Bangla is transliterated, then sounds
/// that are written several ways are folded (`c`/`k`/`q`, `ph`/`f`, doubled
/// letters, `0` read for `o` by OCR...).
String phoneticKey(String word) {
  var s = isBangla(word) ? banglaToLatin(word) : word.toLowerCase();
  s = s
      .replaceAll('0', 'o')
      .replaceAll(RegExp(r'(?<=[a-z])1(?=[a-z])'), 'l')
      .replaceAll('ph', 'f')
      .replaceAll('ck', 'k')
      .replaceAll('qu', 'k')
      .replaceAll(RegExp('[cq]'), 'k')
      .replaceAll('x', 'ks')
      .replaceAll('z', 'j')
      .replaceAll('w', 'o')
      .replaceAll('y', 'i')
      .replaceAll('sh', 's')
      .replaceAll('th', 't')
      .replaceAll('dh', 'd')
      .replaceAll('bh', 'b')
      .replaceAll('kh', 'k')
      .replaceAll('gh', 'g')
      .replaceAll('v', 'b')
      .replaceAll('ee', 'i')
      .replaceAll('oo', 'u')
      .replaceAllMapped(RegExp(r'([a-z])\1+'), (m) => m.group(1)!)
      .replaceAll('h', '');
  // Vowels are where spellings and accents disagree most; keep the first and
  // fold the rest to one letter.
  if (s.length > 1) s = s[0] + s.substring(1).replaceAll(RegExp('[aeiou]'), 'a');
  return s;
}

/// One spelling for the Bangla nukta letters (য় ড় ঢ়): recognisers and
/// keyboards emit both the precomposed and the decomposed form.
String normalizeNukta(String s) => s
    .replaceAll('য়', 'য়')
    .replaceAll('ড়', 'ড়')
    .replaceAll('ঢ়', 'ঢ়');

/// Bangla digits (০-৯) to ASCII, and nukta letters to one form.
String normalizeDigits(String input) {
  final s = normalizeNukta(input);
  final b = StringBuffer();
  for (final c in s.runes) {
    if (c >= 0x09E6 && c <= 0x09EF) {
      b.writeCharCode(0x30 + c - 0x09E6);
    } else {
      b.writeCharCode(c);
    }
  }
  return b.toString();
}
