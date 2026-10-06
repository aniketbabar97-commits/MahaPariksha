/// Lossy Devanagari → Latin key for search, so a student typing in Hinglish ("pratishat",
/// "samanya gyan", "ganit") finds Hindi content, and Devanagari queries still match Hindi text.
///
/// This is not a transliteration standard; both the query and the text go through the same
/// mapping, so only consistency matters. Vowel length is collapsed (ी/ि → i, ू/ु → u), nukta and
/// chandrabindu/anusvara are folded (ं → n), and the inherent 'a' is dropped at the end of a word
/// (schwa deletion: प्रतिशत → pratishat, not pratishata). Latin input is lower-cased and common
/// Hinglish spellings are folded the same way (ee → i, oo → u, aa → a, w → v, ph → f, z → j).
library;

const _vowels = {
  'अ': 'a', 'आ': 'a', 'इ': 'i', 'ई': 'i', 'उ': 'u', 'ऊ': 'u', 'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai',
  'ओ': 'o', 'औ': 'au', 'ऑ': 'o',
};
const _matras = {
  'ा': 'a', 'ि': 'i', 'ी': 'i', 'ु': 'u', 'ू': 'u', 'ृ': 'ri', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au',
  'ॉ': 'o', 'ॅ': 'e',
};
const _consonants = {
  'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'n', 'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh',
  'ञ': 'n', 'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n', 'त': 't', 'थ': 'th', 'द': 'd',
  'ध': 'dh', 'न': 'n', 'प': 'p', 'फ': 'f', 'ब': 'b', 'भ': 'bh', 'म': 'm', 'य': 'y', 'र': 'r',
  'ल': 'l', 'व': 'v', 'श': 'sh', 'ष': 'sh', 'स': 's', 'ह': 'h', 'क़': 'k', 'ख़': 'kh', 'ग़': 'g',
  'ज़': 'j', 'ड़': 'd', 'ढ़': 'dh', 'फ़': 'f', 'ळ': 'l',
};
const _virama = '्';
const _nukta = '़';

bool _isDevanagari(int r) => r >= 0x0900 && r <= 0x097F;

/// The search key of [s]: Devanagari transliterated as above, Latin folded, everything else kept
/// lower-case. Pure and cheap enough to run on a query per keystroke; cache it for big corpora.
String searchKey(String s) {
  final out = StringBuffer();
  final rs = s.runes.toList();
  String ch(int i) => i < rs.length ? String.fromCharCode(rs[i]) : '';
  for (var i = 0; i < rs.length; i++) {
    final r = rs[i];
    final c = ch(i);
    if (!_isDevanagari(r)) {
      out.write(c.toLowerCase());
      continue;
    }
    if (c == _nukta || c == 'ँ' || c == 'ः' || c == '॑' || c == '॒') continue;
    if (c == 'ं') {
      out.write('n');
      continue;
    }
    if (c == _virama) continue; // the consonant before it already skipped its inherent 'a'
    if (_vowels.containsKey(c)) {
      out.write(_vowels[c]);
      continue;
    }
    if (_matras.containsKey(c)) {
      out.write(_matras[c]);
      continue;
    }
    // ज्ञ is said "gy" in Hindi ("gyan"), not "jn".
    if (c == 'ज' && ch(i + 1) == _virama && ch(i + 2) == 'ञ') {
      out.write('gy');
      i += 2;
      final after = ch(i + 1);
      if (after.isNotEmpty && _isDevanagari(after.runes.first) && !_matras.containsKey(after) && after != _virama && after != 'ं') {
        out.write('a');
      }
      continue;
    }
    final cons = _consonants[c] ?? (ch(i + 1) == _nukta ? _consonants[c + _nukta] : null);
    if (cons == null) {
      if (c == '।' || c == '॥') {
        out.write('.');
      } else if (r >= 0x0966 && r <= 0x096F) {
        out.write(String.fromCharCode(r - 0x0966 + 0x30)); // Devanagari digits
      }
      continue;
    }
    out.write(cons);
    // Inherent 'a' unless a matra/virama/nukta/anusvara follows, or this consonant ends the word.
    var j = i + 1;
    if (ch(j) == _nukta) j++;
    final next = ch(j);
    final nextIsDev = next.isNotEmpty && _isDevanagari(next.runes.first);
    if (nextIsDev && !_matras.containsKey(next) && next != _virama && next != 'ं' && next != 'ँ') {
      out.write('a');
    }
  }
  return _foldLatin(out.toString());
}

/// Common Hinglish spelling variants folded to one form, applied to both sides. The short 'a' is
/// dropped everywhere but at the start of a word: Hindi schwa deletion ("relve" vs "relave",
/// "samanya" vs "samany") is irregular and nobody types it consistently, so neither side keeps it.
/// "pratishat", "prtisht" and प्रतिशत all become "prtisht".
String _foldLatin(String s) => s
    .replaceAll('aa', 'a')
    .replaceAll('ee', 'i')
    .replaceAll('oo', 'u')
    .replaceAll('ph', 'f')
    .replaceAll('w', 'v')
    .replaceAll('z', 'j')
    .replaceAll('q', 'k')
    .replaceAll(RegExp(r'[^a-z0-9\s.%+\-/]'), '')
    .replaceAll(RegExp(r'(?<=[a-z])a'), '');

/// Memoised keys for large corpora (question text is immutable for the life of the pack).
final Map<String, String> _keyCache = {};
String cachedSearchKey(String id, String text) => _keyCache[id] ??= searchKey(text);
