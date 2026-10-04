import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/core/app_scope.dart';
import 'package:railpariksha/core/purchases.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/models.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/logic/quiz_builder.dart';
import 'package:railpariksha/screens/quiz_screen.dart';
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
      ..removedAds = true;
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

    expect(find.text('Performance analysis 📊'), findsOneWidget);
    expect(find.textContaining('Negative marking cost you 0.33 marks'), findsOneWidget);
    expect(progress.mocks, hasLength(1));
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
}
