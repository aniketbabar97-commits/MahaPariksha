import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/logic/transliterate.dart';

void main() {
  test('Hinglish and Devanagari spellings meet on one key', () {
    for (final pair in const [
      ('प्रतिशत', 'pratishat'),
      ('प्रतिशत', 'prtisht'),
      ('सामान्य ज्ञान', 'samanya gyan'),
      ('गणित', 'ganit'),
      ('रेलवे', 'relve'),
      ('रेलवे', 'relave'),
      ('भारत', 'bharat'),
      ('भारत', 'bhaarat'),
      ('संविधान', 'sanvidhan'),
      ('वर्ग', 'varg'),
      ('राष्ट्रपति', 'rashtrapati'),
      ('संख्या', 'sankhya'),
      ('विज्ञान', 'vigyan'),
      ('ज़िला', 'jila'),
      ('फ़ोन', 'fon'),
    ]) {
      expect(searchKey(pair.$1), searchKey(pair.$2), reason: '${pair.$1} vs ${pair.$2}');
    }
    expect(searchKey('१२३'), '123');
  });

  test('a Hindi question is found by its Hinglish key', () {
    const q = 'किसी संख्या का 25 प्रतिशत 50 है, तो संख्या क्या है?';
    for (final needle in const ['pratishat', 'sankhya', 'प्रतिशत', 'kya hai', '25 pratishat']) {
      expect(searchKey(q).contains(searchKey(needle)), isTrue, reason: needle);
    }
  });
}
