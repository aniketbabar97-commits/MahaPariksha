import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/core/app_scope.dart';
import 'package:railpariksha/core/purchases.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/models.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/logic/quiz_builder.dart';
import 'package:railpariksha/screens/quiz_screen.dart';
import 'package:railpariksha/screens/today_screen.dart';
import 'package:railpariksha/screens/topic_screen.dart';

Question _q(int i) => Question(
      id: 'mock-test-$i',
      subject: 'maths',
      topic: 'percentage',
      difficulty: 2,
      text: Bi('प्रश्न $i', 'Question $i'),
      optionsHi: const ['क', 'ख', 'ग', 'घ'],
      optionsEn: const ['opt A', 'opt B', 'opt C', 'opt D'],
      answer: 0,
      explanation: const Bi('व्याख्या', 'Explanation'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mock test supports mark-for-review, clear response and palette navigation', (tester) async {
    final repo = ContentRepo();
    await tester.runAsync(repo.load);
    final progress = Progress()
      ..lang = 'en'
      ..removedAds = true
      ..examId = 'rrb_ntpc';
    progress.mocks.add(MockResult(today() - 1, 'rrb_ntpc', 0, 5));
    final spec = QuizSpec(QuizMode.mock, [for (var i = 1; i <= 5; i++) _q(i)], 'मॉक', 'Mock', negative: 1 / 3);

    await tester.pumpWidget(AppScope(
      repo: repo,
      progress: progress,
      purchases: PurchaseManager(progress),
      child: MaterialApp(home: QuizScreen(spec: spec)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Question 1'), findsOneWidget);
    expect(find.text('Clear response'), findsOneWidget);

    // Answer Q1, then clear it again.
    await tester.tap(find.text('opt B'));
    await tester.pump();
    await tester.tap(find.text('Clear response'));
    await tester.pump();

    // Answer Q1 for real and mark it for review.
    await tester.tap(find.text('opt A'));
    await tester.pump();
    await tester.tap(find.text('Mark for review'));
    await tester.pump();
    expect(find.text('Unmark review'), findsOneWidget);

    // Move to Q2 (visit without answering), then jump to Q5 through the palette.
    await tester.tap(find.text('Save & next →'));
    await tester.pumpAndSettle();
    expect(find.text('Question 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Question palette'));
    await tester.pumpAndSettle();
    expect(find.text('Answered & marked'), findsWidgets);
    expect(find.text('Not visited'), findsWidgets);
    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();
    expect(find.text('Question 5'), findsOneWidget);

    // Last question: submit summary shows the palette breakdown.
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Submit test?'), findsOneWidget);
    expect(find.textContaining('will be evaluated'), findsOneWidget);
    await tester.tap(find.text('Wait'));
    await tester.pumpAndSettle();
    expect(find.text('Question 5'), findsOneWidget);

    // Answer Q5 wrong, submit for real, and land on the analysed results.
    await tester.tap(find.text('opt B'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
    await tester.pumpAndSettle();

    expect(progress.mocks, hasLength(2));
    // Score 1 - 1/3 = 0.67 of 5 = 13% up on the previous 0/5.
    expect(find.text('+13% vs last mock'), findsOneWidget);

    // The analysis sits below the "Your next step" card, further down the list.
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Performance analysis 📊'), 300, scrollable: list);
    expect(find.text('Performance analysis 📊'), findsOneWidget);
    expect(find.textContaining('Negative marking cost you 0.33 marks'), findsOneWidget);

    // One wrong answer (Q5): retrying opens a practice round of just that question.
    await tester.scrollUntilVisible(find.text('Retry the 1 you got wrong now'), -300, scrollable: list);
    await tester.tap(find.text('Retry the 1 you got wrong now'));
    await tester.pumpAndSettle();
    expect(find.text('Question 5'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('topic screen shows the learner level that drives practice difficulty', (tester) async {
    final repo = ContentRepo();
    await tester.runAsync(repo.load);
    final progress = Progress()..lang = 'en';
    await tester.pumpWidget(AppScope(
      repo: repo,
      progress: progress,
      purchases: PurchaseManager(progress),
      child: MaterialApp(home: TopicScreen(subject: repo.subject('maths')!, topic: repo.topic('maths', 'percentage')!)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your level: Getting started'), findsOneWidget);
  });

  testWidgets('leaving a mock saves it, and resuming restores answers, marks and position', (tester) async {
    final repo = ContentRepo();
    await tester.runAsync(repo.load);
    final progress = Progress()
      ..lang = 'en'
      ..removedAds = true;
    final qs = repo.questionsInSubject('maths').take(5).toList();
    final spec = QuizSpec(QuizMode.mock, qs, 'मॉक', 'Mock', negative: 1 / 3, timeLimit: const Duration(minutes: 5));

    await tester.pumpWidget(AppScope(
      repo: repo,
      progress: progress,
      purchases: PurchaseManager(progress),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(children: [
              TextButton(onPressed: () => startQuiz(context, spec), child: const Text('start')),
              TextButton(onPressed: () => resumeMock(context, progress.pausedMock!), child: const Text('resume')),
            ]),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(qs[0].optionsEn[2]).first);
    await tester.pump();
    await tester.tap(find.text('Save & next →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark for review'));
    await tester.pump();
    await tester.tap(find.text('Save & next →'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Leave the test?'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    final saved = progress.pausedMock!;
    expect(saved.answers[0], 2);
    expect(saved.marked, contains(1));
    expect(saved.index, 2);
    expect(saved.questionIds, [for (final q in qs) q.id]);

    await tester.tap(find.text('resume'));
    await tester.pumpAndSettle();
    expect(find.text(qs[2].text.en), findsOneWidget);
    await tester.tap(find.byTooltip('Question palette'));
    await tester.pumpAndSettle();
    // Q1 answered, Q2 marked, Q3 current (not answered), Q4-5 not visited.
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text('Answered')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Marked for review')), findsOneWidget);
  });

  testWidgets('Today shows a resume card for a paused mock, and discarding removes it', (tester) async {
    final repo = ContentRepo();
    await tester.runAsync(repo.load);
    final ids = repo.questionsInSubject('maths').take(3).map((q) => q.id).toList();
    final progress = Progress()
      ..lang = 'en'
      ..onboarded = true
      ..examId = 'rrb_ntpc'
      ..removedAds = true
      ..pausedMock = PausedMock(
        examId: 'rrb_ntpc',
        questionIds: ids,
        titleHi: 'मॉक',
        titleEn: 'Quick mock',
        negative: 1 / 3,
        timeLimitSec: 600,
        remainingSec: 125,
        answers: const [0, null, null],
        marked: const [],
        visited: const [0],
        index: 0,
        timeMs: const [0, 0, 0],
      );
    await tester.pumpWidget(AppScope(
      repo: repo,
      progress: progress,
      purchases: PurchaseManager(progress),
      child: MaterialApp(home: Scaffold(body: TodayScreen(onNavigate: (_) {}))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Resume your test'), findsOneWidget);
    expect(find.textContaining('1/3 answered'), findsOneWidget);
    expect(find.textContaining('2:05 left'), findsOneWidget);

    await tester.tap(find.byTooltip('Discard test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(progress.pausedMock, isNull);
    expect(find.text('Resume your test'), findsNothing);
    await tester.pump(const Duration(seconds: 1)); // let Progress's debounced save fire
  });

  testWidgets('the palette groups a section-wise paper under subject headers', (tester) async {
    final repo = ContentRepo();
    await tester.runAsync(repo.load);
    final progress = Progress()
      ..lang = 'en'
      ..removedAds = true;
    final qs = [...repo.questionsInSubject('maths').take(2), ...repo.questionsInSubject('reasoning').take(3)];
    final spec = QuizSpec(QuizMode.mock, qs, 'मॉक', 'Mock');
    await tester.pumpWidget(AppScope(
      repo: repo,
      progress: progress,
      purchases: PurchaseManager(progress),
      child: MaterialApp(home: QuizScreen(spec: spec)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Question palette'));
    await tester.pumpAndSettle();
    expect(find.text('${repo.subject('maths')!.name.en} · 0/2'), findsOneWidget);
    expect(find.text('${repo.subject('reasoning')!.name.en} · 0/3'), findsOneWidget);
  });

  testWidgets('answer options announce the result to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = ContentRepo();
    await tester.runAsync(repo.load);
    final progress = Progress()..lang = 'en';
    final spec = QuizSpec(QuizMode.practice, [_q(1)], 'अभ्यास', 'Practice');
    await tester.pumpWidget(AppScope(
      repo: repo,
      progress: progress,
      purchases: PurchaseManager(progress),
      child: MaterialApp(home: QuizScreen(spec: spec)),
    ));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('A, opt A'), findsOneWidget);

    await tester.tap(find.text('opt B'));
    await tester.pumpAndSettle();
    // A celebration dialog may follow the first answer of the day; dismiss it.
    if (find.byType(Dialog).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
    expect(find.bySemanticsLabel('A, opt A, correct answer'), findsOneWidget);
    expect(find.bySemanticsLabel('B, opt B, your answer, wrong'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    handle.dispose();
  });
}
