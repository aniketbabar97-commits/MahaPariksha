import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/core/app_scope.dart';
import 'package:railpariksha/core/purchases.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/data/pyq_repo.dart';
import 'package:railpariksha/screens/pyq_modes.dart';
import 'package:railpariksha/screens/pyq_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the topic index adds up to the year sets and each shard matches its count', () async {
    final repo = PyqRepo();
    final sets = await repo.sets();
    final topics = await repo.topics();
    expect(topics, isNotEmpty, reason: 'run pipeline/build_bundle.py to generate assets/pyq/topics/');
    // The app hides "years" with only a handful of stray questions, so the visible sets can sum to
    // slightly less than the topic index (which still includes those strays).
    final inTopics = topics.fold<int>(0, (a, t) => a + t.count);
    final inSets = sets.fold<int>(0, (a, s) => a + s.count);
    expect(inTopics, greaterThanOrEqualTo(inSets));
    expect(inTopics - inSets, lessThan(200));
    for (final t in topics.take(4)) {
      final qs = await repo.topicQuestions(t);
      expect(qs, hasLength(t.count));
      expect(qs.every((q) => q.subject == t.subject && q.topic == t.topic), isTrue);
      expect(t.byExam.values.fold<int>(0, (a, b) => a + b), t.count);
    }
  });

  test('countFor sums only the exams whose name starts with the prefix', () {
    const t = PyqTopic('maths', 'percentage', 30, 'x', {'RRB NTPC Graduate CBT-1': 10, 'RRB NTPC UG CBT-1': 5, 'RRB Group D CBT': 15});
    expect(t.countFor('RRB NTPC'), 15);
    expect(t.countFor('RRB Group D'), 15);
    expect(t.countFor(null), 30);
    expect(t.countFor('RPF SI'), 0);
  });

  test('sampleBySubject draws the quota per subject from a few year files', () async {
    final repo = PyqRepo();
    final family = (await repo.sets()).where((s) => s.railway && s.exam.startsWith('RRB NTPC')).toList();
    expect(family, isNotEmpty);
    final drawn = await repo.sampleBySubject(family, {'maths': 12, 'reasoning': 8});
    expect(drawn['maths'], hasLength(12));
    expect(drawn['reasoning'], hasLength(8));
    expect(drawn['maths']!.every((q) => q.subject == 'maths'), isTrue);
    expect({...drawn['maths']!.map((q) => q.id)}, hasLength(12), reason: 'no repeats');
  });

  test('a test of n questions is allowed 0.9 minutes each', () {
    expect(pyqTestTime(100).inMinutes, 90);
    expect(pyqTestTime(25).inMinutes, 23);
    expect(pyqTestTime(1).inMinutes, 1);
  });

  Future<void> open(WidgetTester tester) async {
    PyqAccess.reset();
    final repo = ContentRepo();
    await tester.runAsync(repo.load);
    final progress = Progress()
      ..lang = 'en'
      ..examId = 'rrb_group_d'
      ..removedAds = true;
    await tester.pumpWidget(AppScope(
      repo: repo,
      progress: progress,
      purchases: PurchaseManager(progress),
      child: const MaterialApp(home: PyqScreen()),
    ));
    await tester.runAsync(() async {
      await pyqRepo.sets();
      await pyqRepo.topics();
    });
    await tester.pumpAndSettle();
  }

  testWidgets('the PYQ screen has three ways in: by year, by topic, full exams', (tester) async {
    await open(tester);
    expect(find.text('By year'), findsOneWidget);
    expect(find.text('By topic'), findsOneWidget);
    expect(find.text('Full exams'), findsOneWidget);

    await tester.tap(find.text('By topic'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PYQs'), findsWidgets, reason: 'topics list how many PYQs they have');
    expect(find.text('Mathematics'), findsWidgets);

    await tester.tap(find.text('Full exams'));
    await tester.pumpAndSettle();
    expect(find.text('Final full exam'), findsOneWidget);
    expect(find.text('Subject tests'), findsOneWidget);
    expect(find.textContaining('negative marking'), findsWidgets);
  });

  testWidgets('a topic offers practice and a timed topic test', (tester) async {
    await open(tester);
    await tester.tap(find.text('By topic'));
    await tester.pumpAndSettle();
    final topic = (await tester.runAsync(() => pyqRepo.topics()))!.firstWhere((t) => t.subject == 'maths');
    await tester.runAsync(() => pyqRepo.topicQuestions(topic)); // load for real: isolates don't finish in fake time
    final tile = find.byIcon(Icons.topic_outlined).first;
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    // Wait on the outcome, not a fixed time: CI runners load the topic file much more slowly.
    for (var i = 0; i < 50 && find.textContaining('Topic test (').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.textContaining('Practice ('), findsOneWidget);
    expect(find.textContaining('Topic test ('), findsOneWidget);
  });
}
