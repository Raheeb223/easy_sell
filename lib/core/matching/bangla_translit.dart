/// Rough Bangla -> Latin transliteration, for MATCHING only (never shown).
///
/// Shopkeepers say brand names in Bangla (`পেপসি`, `কোকাকোলা`) while the
/// product may be saved in English (`Pepsi`, `Coca-Cola`), and the other way
/// round. Both sides are brought to Latin letters here and then folded by
/// `phoneticKey`, so close-enough spellings meet.
library;

bool isBangla(String s) => s.runes.any((c) => c >= 0x0980 && c <= 0x09FF);

const _vowels = {
  'অ': 'a', 'আ': 'a', 'ই': 'i', 'ঈ': 'i', 'উ': 'u', 'ঊ': 'u', 'ঋ': 'ri',
  'এ': 'e', 'ঐ': 'oi', 'ও': 'o', 'ঔ': 'ou',
};

const _signs = {
  'া': 'a', 'ি': 'i', 'ী': 'i', 'ু': 'u', 'ূ': 'u', 'ৃ': 'ri', 'ে': 'e',
  'ৈ': 'oi', 'ো': 'o', 'ৌ': 'ou',
};

const _consonants = {
  'ক': 'k', 'খ': 'kh', 'গ': 'g', 'ঘ': 'gh', 'ঙ': 'ng', 'চ': 'ch', 'ছ': 'ch',
  'জ': 'j', 'ঝ': 'jh', 'ঞ': 'n', 'ট': 't', 'ঠ': 'th', 'ড': 'd', 'ঢ': 'dh',
  'ণ': 'n', 'ত': 't', 'থ': 'th', 'দ': 'd', 'ধ': 'dh', 'ন': 'n', 'প': 'p',
  'ফ': 'f', 'ব': 'b', 'ভ': 'bh', 'ম': 'm', 'য': 'j', 'র': 'r', 'ল': 'l',
  'শ': 'sh', 'ষ': 'sh', 'স': 's', 'হ': 'h', 'ড়': 'r', 'ঢ়': 'rh', 'য়': 'y',
};

const _other = {'ৎ': 't', 'ং': 'ng', 'ঃ': 'h', 'ঁ': '', '্': ''};

const _hasanta = '্';

String banglaToLatin(String word) {
  // Callers pass text through `normalizeDigits`, which already folds the
  // nukta letters to their precomposed form.
  final chars = word.split('');
  final out = StringBuffer();
  for (var i = 0; i < chars.length; i++) {
    final c = chars[i];
    final cons = _consonants[c];
    if (cons != null) {
      out.write(cons);
      final next = i + 1 < chars.length ? chars[i + 1] : null;
      // Inherent vowel unless a vowel sign or hasanta follows.
      if (next == null || (!_signs.containsKey(next) && next != _hasanta)) {
        if (next != null || chars.length <= 2) out.write('a');
      }
      continue;
    }
    out.write(_vowels[c] ?? _signs[c] ?? _other[c] ?? (c.codeUnitAt(0) < 128 ? c : ''));
  }
  return out.toString();
}
