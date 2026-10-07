import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/logic/question_reports.dart';

void main() {
  test('payload trims long values and normalises the language', () {
    final p = QuestionReports.payload(id: 'x' * 200, reason: 'r' * 200, lang: 'fr', pyq: true);
    expect((p['qid'] as String).length, QuestionReports.maxId);
    expect((p['reason'] as String).length, QuestionReports.maxReason);
    expect(p['lang'], 'hi');
    expect(p['pyq'], true);
    expect(p.keys.toSet(), {'qid', 'reason', 'lang', 'pyq'});
  });

  test('send is a quiet no-op without Firebase', () async {
    expect(await QuestionReports.send(id: 'q1', reason: 'Answer is wrong', lang: 'en', pyq: false), isFalse);
  });
}
