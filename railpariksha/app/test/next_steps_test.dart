import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/core/app_scope.dart';
import 'package:railpariksha/core/purchases.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/models.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/logic/next_steps.dart';
import 'package:railpariksha/logic/quiz_builder.dart';
import 'package:railpariksha/screens/results_screen.dart';

Question _q(String id, String topic, {int answer = 0}) => Question(
      id: id,
      subject: 'maths',
      topic: topic,
      difficulty: 2,
      text: Bi('प्रश्न $id', 'Question $id'),
      optionsHi: const ['क', 'ख', 'ग', 'घ'],
      optionsEn: const ['a', 'b', 'c', 'd'],
      answer: answer,
      explanation: const Bi('व्याख्या', 'Explanation'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NextSteps', () {
    final qs = [
      _q('1', 'percentage'), _q('2', 'percentage'), _q('3', 'percentage'), // 3/3 right
      _q('4', 'profit_loss'), _q('5', 'profit_loss'), _q('6', 'profit_loss'), // 1/3 right
      _q('7', 'time_work'), _q('8', 'time_work'), // 0/2 right
      _q('9', 'average'), // skipped
    ];
    final answers = <int?>[0, 0, 0, 0, 1, 1, 2, 2, null];

    test('flags weak topics weakest first and praises the perfect one', () {
      final s = NextSteps.from(qs, answers, const []);
      expect(s.weak.map((v) => v.topic), ['time_work', 'profit_loss']);
      expect(s.strong?.topic, 'percentage');
      expect(s.weak.first.sessionCorrect, 0);
      expect(s.weak.first.sessionAttempts, 2);
    });

    test('a skipped question says nothing about a topic', () {
      final s = NextSteps.from(qs, answers, const []);
      expect([...s.weak.map((v) => v.topic), s.strong?.topic], isNot(contains('average')));
    });

    test('one slip in a well-practised topic is not flagged as weak', () {
      // 1/3 this quiz, but 18/20 overall (history includes this quiz).
      final s = NextSteps.from(qs, answers, const [TopicStat('maths', 'profit_loss', 20, 18)]);
      expect(s.weak.map((v) => v.topic), ['time_work']);
    });

    test('caps the list at three weak topics', () {
      final many = [for (var i = 0; i < 5; i++) _q('w$i', 't$i')];
      final s = NextSteps.from(many, List<int?>.filled(5, 1), const []);
      expect(s.weak, hasLength(NextSteps.maxWeak));
    });
  });

  testWidgets('results show "Your next step" with one-tap fixes for a weak topic', (tester) async {
    final repo = ContentRepo();
    await tester.runAsync(repo.load);
    final progress = Progress()
      ..lang = 'en'
      ..removedAds = true
      ..examId = 'rrb_ntpc';
    final pool = repo.questionsInSubject('maths').where((q) => q.topic == 'percentage').take(3).toList();
    final answers = [for (final q in pool) (q.answer + 1) % 4]; // all wrong
    for (var i = 0; i < pool.length; i++) {
      progress.recordAnswer(pool[i].id, false);
    }
    await tester.pumpWidget(AppScope(
      repo: repo,
      progress: progress,
      purchases: PurchaseManager(progress),
      child: MaterialApp(
        home: ResultsScreen(
          spec: QuizSpec(QuizMode.practice, pool, 'अभ्यास', 'Practice'),
          answers: answers,
          xpEarned: 6,
          elapsed: const Duration(minutes: 1),
          speedScore: 0,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Your next step 🎯'), findsOneWidget);
    expect(find.text(repo.topic('maths', 'percentage')!.name.en), findsOneWidget);
    expect(find.text('This quiz 0/3 · overall 0%'), findsOneWidget);
    expect(find.text('Practise 10'), findsOneWidget);

    await tester.ensureVisible(find.text('Practise 10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practise 10'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 10'), findsOneWidget, reason: 'opens a 10-question practice set on that topic');
    await tester.pump(const Duration(seconds: 1));
  });
}
