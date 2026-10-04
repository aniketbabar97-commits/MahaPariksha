import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/data/models.dart';
import 'package:railpariksha/logic/mock_analysis.dart';
import 'package:railpariksha/logic/quiz_builder.dart';

Question _q(String id, String subject, {int answer = 0}) => Question(
      id: id,
      subject: subject,
      topic: 't',
      difficulty: 2,
      text: const Bi('प्र', 'Q'),
      optionsHi: const ['a', 'b', 'c', 'd'],
      optionsEn: const ['a', 'b', 'c', 'd'],
      answer: answer,
      explanation: const Bi('', ''),
    );

QuizSpec _spec(List<Question> qs, {double negative = 1 / 3, Duration? limit}) =>
    QuizSpec(QuizMode.mock, qs, 'मॉक', 'Mock', negative: negative, timeLimit: limit);

void main() {
  group('MockAnalysis', () {
    test('breaks results down per subject, largest subject first', () {
      final qs = [
        _q('1', 'maths'),
        _q('2', 'maths'),
        _q('3', 'maths'),
        _q('4', 'gk'),
      ];
      final a = MockAnalysis.from(_spec(qs), [0, 1, null, 0], null);
      expect(a.subjects.map((s) => s.subject), ['maths', 'gk']);
      final maths = a.subjects.first;
      expect(maths.total, 3);
      expect(maths.attempted, 2);
      expect(maths.correct, 1);
      expect(maths.net(1 / 3), closeTo(1 - 1 / 3, 1e-9));
      expect(a.attempted, 3);
      expect(a.correct, 2);
      expect(a.marksLostToNegative, closeTo(1 / 3, 1e-9));
    });

    test('flags over-attempting when most attempts are wrong', () {
      final qs = [for (var i = 0; i < 10; i++) _q('$i', 'maths')];
      final answers = <int?>[0, 0, 1, 1, 1, 1, null, null, null, null];
      expect(MockAnalysis.from(_spec(qs), answers, null).tip, StrategyTip.overAttempting);
    });

    test('flags under-attempting when accurate but many skipped', () {
      final qs = [for (var i = 0; i < 10; i++) _q('$i', 'maths')];
      final answers = <int?>[0, 0, 0, 0, 0, 0, null, null, null, null];
      expect(MockAnalysis.from(_spec(qs), answers, null).tip, StrategyTip.underAttempting);
    });

    test('gives no attempt-strategy tip without negative marking', () {
      final qs = [for (var i = 0; i < 10; i++) _q('$i', 'maths')];
      final answers = <int?>[0, 0, 1, 1, 1, 1, null, null, null, null];
      expect(MockAnalysis.from(_spec(qs, negative: 0), answers, null).tip, isNull);
    });

    test('reports average time, exam pace and genuinely slow questions only', () {
      final qs = [for (var i = 0; i < 4; i++) _q('$i', 'maths')];
      final times = const [Duration(seconds: 10), Duration(seconds: 12), Duration(seconds: 90), Duration(seconds: 8)];
      final a = MockAnalysis.from(_spec(qs, limit: const Duration(minutes: 4)), [0, 0, 0, 0], times);
      expect(a.avgTime, const Duration(seconds: 30));
      expect(a.targetPace, const Duration(minutes: 1));
      expect(a.slowest, [2]);
    });
  });
}
