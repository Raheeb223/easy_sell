/// Everyday Bangladeshi shop words in Bangla script, Banglish and English,
/// each mapped to one concept, so `চিনি` / `chini` / `sugar` all meet
/// (the cross-script rule the Gemini prompt used to carry).
///
/// Keys are lower-case words as spoken or written; the value is the concept.
/// The matcher compares concepts first, then phonetic spelling, so a word
/// missing here still matches by sound.
library;

const _groups = <String, List<String>>{
  'rice': ['rice', 'chal', 'chaal', 'চাল', 'chawal', 'bhat', 'ভাত'],
  'sugar': ['sugar', 'chini', 'cini', 'চিনি'],
  'salt': ['salt', 'lobon', 'labon', 'lobn', 'লবণ', 'লবন', 'nun', 'নুন'],
  'oil': ['oil', 'tel', 'teil', 'তেল'],
  'soybean': ['soybean', 'soyabean', 'soya', 'soy', 'সয়াবিন', 'সয়াবিন'],
  'mustard': ['mustard', 'sorisha', 'shorisha', 'sorsha', 'সরিষা', 'সর্ষে'],
  'lentil': ['lentil', 'lentils', 'dal', 'daal', 'ডাল', 'masur', 'mosur', 'মসুর'],
  'flour': ['flour', 'atta', 'ata', 'আটা', 'moyda', 'maida', 'ময়দা', 'ময়দা'],
  'semolina': ['semolina', 'suji', 'sooji', 'সুজি'],
  'potato': ['potato', 'potatoes', 'alu', 'aloo', 'আলু'],
  'onion': ['onion', 'onions', 'peyaj', 'piyaj', 'pyaj', 'পেঁয়াজ', 'পেয়াজ', 'পিয়াজ'],
  'garlic': ['garlic', 'roshun', 'rosun', 'রসুন'],
  'ginger': ['ginger', 'ada', 'aada', 'আদা'],
  'chili': ['chili', 'chilli', 'chillies', 'morich', 'marich', 'মরিচ', 'লঙ্কা'],
  'turmeric': ['turmeric', 'holud', 'halud', 'হলুদ'],
  'cumin': ['cumin', 'jira', 'zira', 'জিরা'],
  'spice': ['spice', 'spices', 'masala', 'mosla', 'moshla', 'মসলা', 'মশলা'],
  'egg': ['egg', 'eggs', 'dim', 'deem', 'ডিম'],
  'milk': ['milk', 'dudh', 'doodh', 'দুধ'],
  'yogurt': ['yogurt', 'curd', 'doi', 'dahi', 'দই'],
  'butter': ['butter', 'makhon', 'মাখন'],
  'ghee': ['ghee', 'ghi', 'ঘি'],
  'tea': ['tea', 'cha', 'chai', 'চা'],
  'coffee': ['coffee', 'kofi', 'কফি'],
  'water': ['water', 'pani', 'jol', 'পানি', 'জল'],
  'bread': ['bread', 'pauruti', 'paoruti', 'পাউরুটি', 'ruti', 'রুটি'],
  'biscuit': ['biscuit', 'biscuits', 'biskut', 'biskit', 'বিস্কুট', 'cookies'],
  'cake': ['cake', 'kek', 'কেক'],
  'noodles': ['noodles', 'noodle', 'nudls', 'নুডুলস', 'নুডলস'],
  'chanachur': ['chanachur', 'chanachur', 'চানাচুর'],
  'puffed rice': ['muri', 'moori', 'মুড়ি', 'মুড়ি'],
  'flattened rice': ['chira', 'chida', 'চিড়া', 'চিড়া'],
  'chickpea': ['chickpea', 'chickpeas', 'chola', 'chhola', 'ছোলা'],
  'soap': ['soap', 'sabun', 'saban', 'সাবান'],
  'detergent': ['detergent', 'washing', 'powder', 'ডিটারজেন্ট', 'gura', 'গুঁড়া'],
  'shampoo': ['shampoo', 'shampu', 'শ্যাম্পু'],
  'toothpaste': ['toothpaste', 'paste', 'majon', 'মাজন', 'টুথপেস্ট'],
  'banana': ['banana', 'bananas', 'kola', 'kela', 'কলা'],
  'apple': ['apple', 'apples', 'apel', 'আপেল'],
  'orange': ['orange', 'oranges', 'komla', 'কমলা'],
  'tomato': ['tomato', 'tomatoes', 'tometo', 'টমেটো'],
  'eggplant': ['eggplant', 'brinjal', 'begun', 'বেগুন'],
  'fish': ['fish', 'mach', 'maach', 'মাছ'],
  'meat': ['meat', 'mangsho', 'mangso', 'মাংস'],
  'chicken': ['chicken', 'murgi', 'murgir', 'মুরগি', 'মুরগী'],
  'beef': ['beef', 'goru', 'gorur', 'গরু', 'গরুর'],
  'sweet': ['sweet', 'sweets', 'mishti', 'misti', 'মিষ্টি'],
  'candle': ['candle', 'candles', 'mombati', 'মোমবাতি'],
  'matches': ['matches', 'matchbox', 'diyashlai', 'ম্যাচ', 'দিয়াশলাই'],
  'mosquito coil': ['coil', 'koyel', 'কয়েল'],
  'battery': ['battery', 'batteries', 'bettari', 'ব্যাটারি'],
  'notebook': ['notebook', 'khata', 'খাতা'],
  'pen': ['pen', 'kolom', 'কলম'],
  'loose': ['loose', 'khola', 'khula', 'খোলা', 'khuchra', 'খুচরা'],
  'drink': ['drink', 'drinks', 'cold', 'soft', 'ড্রিংকস'],
  'juice': ['juice', 'jus', 'জুস'],
  'chips': ['chips', 'cips', 'চিপস'],
  'chocolate': ['chocolate', 'choklet', 'চকলেট'],
  'cigarette': ['cigarette', 'cigarettes', 'sigaret', 'সিগারেট', 'বিড়ি', 'biri'],
};

/// word -> concept, built once.
final Map<String, String> groceryConcepts = {
  for (final e in _groups.entries)
    for (final w in e.value) w: '#${e.key}',
};
