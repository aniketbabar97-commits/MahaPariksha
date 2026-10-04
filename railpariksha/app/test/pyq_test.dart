import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/core/app_scope.dart';
import 'package:railpariksha/logic/quiz_builder.dart';
import 'package:railpariksha/core/ads.dart';
import 'package:railpariksha/core/purchases.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/models.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/data/pyq_repo.dart';
import 'package:railpariksha/screens/pyq_screen.dart';

void main() {
  test('courtesy access when no ad can load: opens the section, but only twice per session', () {
    PyqAccess.reset();
    final p = Progress();
    expect(PyqAccess.unlocked(p), isFalse);
    expect(PyqAccess.grantCourtesy(), isTrue);
    expect(PyqAccess.unlocked(p), isTrue);
    expect(PyqAccess.remaining(), lessThanOrEqualTo(PyqAccess.courtesyWindow));
    expect(PyqAccess.grantCourtesy(), isTrue);
    expect(PyqAccess.grantCourtesy(), isFalse, reason: 'limited to ${PyqAccess.courtesyLimit} a session');
    PyqAccess.reset();
    expect(PyqAccess.grantCourtesy(), isTrue, reason: 'reset() starts a fresh session');
    PyqAccess.reset();
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  test('English-only PYQ items fall back to English for the Hindi fields', () {
    final q = Question.fromJson({
      'id': 'pyq-x', 's': 'maths', 't': 'percentage', 'd': 2,
      'q_en': 'What is 10% of 50?', 'o_en': ['5', '10', '15', '20'], 'a': 0,
      'e_en': 'Correct answer: 5.', 'pyq': 'SSC CGL 2024 · 17 Sep 2024 · Shift 2',
    });
    expect(q.text.of('hi'), 'What is 10% of 50?');
    expect(q.options('hi'), ['5', '10', '15', '20']);
    expect(q.explanation.of('hi'), 'Correct answer: 5.');
    expect(q.pyq, 'SSC CGL 2024 · 17 Sep 2024 · Shift 2');
  });

  test('the PYQ pack index matches its set files', () async {
    final repo = PyqRepo();
    final sets = await repo.sets();
    expect(sets, isNotEmpty, reason: 'run pipeline/build_bundle.py to generate assets/pyq/');
    expect(sets.first.railway, isTrue, reason: 'railway papers are listed first');
    final je = sets.first;
    final qs = await repo.questions(je);
    expect(qs, hasLength(je.count));
    for (final q in qs) {
      expect(q.pyq, isNotNull);
      expect(q.optionsEn, hasLength(4));
      expect(q.optionsHi, hasLength(4));
      expect(q.text.en.trim(), isNotEmpty);
      expect(q.answer, inInclusiveRange(0, 3));
    }
    for (final p in je.papers) {
      expect(qs.where((q) => q.pyq == p.label), hasLength(p.count));
    }
  });

  Future<Progress> pump(WidgetTester tester, {required bool adFree}) async {
    final repo = ContentRepo();
    await tester.runAsync(repo.load);
    final progress = Progress()
      ..lang = 'en'
      ..examId = 'rrb_group_d'
      ..removedAds = adFree;
    await tester.pumpWidget(AppScope(
      repo: repo,
      progress: progress,
      purchases: PurchaseManager(progress),
      child: const MaterialApp(home: PyqScreen()),
    ));
    await tester.runAsync(() => pyqRepo.sets());
    await tester.pumpAndSettle();
    return progress;
  }

  testWidgets("the PYQ list puts the student's own exam first", (tester) async {
    PyqAccess.reset();
    await pump(tester, adFree: true); // exam: rrb_group_d
    final tiles = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();
    final firstSet = tiles.indexWhere((t) => t.startsWith('RRB Group D') || t.startsWith('RPF') || t.startsWith('RRB ALP'));
    expect(tiles[firstSet], startsWith('RRB Group D'), reason: 'Group D papers are listed before RPF/ALP for a Group D student');
  });

  testWidgets('an ad-free user opens a railway paper straight into an exam-style test', (tester) async {
    PyqAccess.reset();
    await pump(tester, adFree: true);
    expect(find.text('Railway papers 🚆'), findsOneWidget);
    expect(find.textContaining('Ad-free'), findsOneWidget);

    final set = (await tester.runAsync(() => pyqRepo.sets()))!.firstWhere((s) => s.railway);
    // Load (and cache) the set for real first: the screen's own load would run
    // inside the test's fake clock, where its background isolate never finishes.
    await tester.runAsync(() => pyqRepo.questions(set));
    await tester.tap(find.text(set.title).first);
    await tester.pumpAndSettle();
    expect(find.text('Attempt a full paper 📝'), findsOneWidget);

    final paper = set.papers.first;
    await tester.scrollUntilVisible(find.text(paper.shortLabel), 200);
    await tester.tap(find.text(paper.shortLabel));
    await tester.pumpAndSettle();
    expect(find.text('PYQ · ${paper.label}'), findsOneWidget);
    expect(find.textContaining('1 / '), findsOneWidget);
    expect(find.text('Mark for review'), findsOneWidget, reason: 'papers use the CBT exam interface');
  });

  testWidgets('without ad-free access, starting PYQ practice asks to watch an ad first', (tester) async {
    PyqAccess.reset();
    await pump(tester, adFree: false);
    expect(find.textContaining('one ad'), findsNothing, reason: 'ad mechanics are explained in the unlock dialog only');

    final set = (await tester.runAsync(() => pyqRepo.sets()))!.firstWhere((s) => s.railway);
    // Load (and cache) the set for real first: the screen's own load would run
    // inside the test's fake clock, where its background isolate never finishes.
    await tester.runAsync(() => pyqRepo.questions(set));
    await tester.tap(find.text(set.title).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Mixed practice'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock PYQs'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock PYQs'), findsNothing);
    expect(find.textContaining('Mixed practice'), findsOneWidget, reason: 'declining stays on the set screen');
  });

  testWidgets('a full paper asks for its own ad, even while the practice window is open', (tester) async {
    PyqAccess.reset();
    PyqAccess.grant(); // practice window open
    await pump(tester, adFree: false);
    final set = (await tester.runAsync(() => pyqRepo.sets()))!.firstWhere((s) => s.railway);
    await tester.runAsync(() => pyqRepo.questions(set));
    await tester.tap(find.text(set.title).first);
    await tester.pumpAndSettle();
    final paper = set.papers.first;
    await tester.scrollUntilVisible(find.text(paper.shortLabel), 200);
    await tester.tap(find.text(paper.shortLabel));
    await tester.pumpAndSettle();
    expect(find.text('Unlock this paper'), findsOneWidget, reason: 'the 30-min window does not cover full papers');
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    PyqAccess.reset();
  });

  test('per-paper access: one paper unlocked does not unlock another, ad-free covers all', () {
    PyqAccess.reset();
    final free = Progress();
    expect(PyqAccess.paperUnlocked(free, 'A'), isFalse);
    PyqAccess.grantPaper('A');
    expect(PyqAccess.paperUnlocked(free, 'A'), isTrue);
    expect(PyqAccess.paperUnlocked(free, 'B'), isFalse);
    expect(PyqAccess.paperUnlocked(Progress()..removedAds = true, 'B'), isTrue);
    expect(PyqAccess.grantCourtesy(paper: 'B'), isTrue, reason: 'a failed ad load opens that paper');
    expect(PyqAccess.paperUnlocked(free, 'B'), isTrue);
    expect(PyqAccess.unlocked(free), isFalse, reason: 'a paper courtesy does not open the practice window');
    PyqAccess.reset();
  });

  test('interstitial pacing: 2 free quizzes, then every 10th, never closer than 3 minutes', () {
    AdPacing.reset();
    final t0 = DateTime(2026, 10, 4, 12);
    expect([for (var n = 1; n <= 21; n++) if (AdPacing.shouldShow(n, now: t0)) n], [10, 20]);
    AdPacing.markShown(t0);
    expect(AdPacing.shouldShow(20, now: t0.add(const Duration(minutes: 1))), isFalse, reason: 'too soon after the last one');
    expect(AdPacing.shouldShow(20, now: t0.add(const Duration(minutes: 3))), isTrue);
    expect(AdPacing.due(10), isTrue);
    expect(AdPacing.due(3), isFalse);
    expect(AdPacing.eligibleMode(QuizMode.placement), isFalse);
    expect(AdPacing.eligibleMode(QuizMode.speed), isFalse);
    expect(AdPacing.eligibleMode(QuizMode.pyqPaper), isTrue);
    AdPacing.reset();
  });

  test('app-open ad: only on a return after a long absence, once per 4h, never mid-quiz or for ad-free', () {
    final now = DateTime(2026, 10, 4, 12);
    bool show({bool removed = false, int quizzes = 5, int awayMin = 45, DateTime? last, bool busy = false}) =>
        AppOpenAdManager.shouldShow(
            removedAds: removed, quizzesDone: quizzes, away: Duration(minutes: awayMin), now: now, lastShown: last, busy: busy);
    expect(show(), isTrue);
    expect(show(awayMin: 10), isFalse, reason: 'a quick app switch is not a return');
    expect(show(quizzes: 2), isFalse, reason: 'new users get a grace period');
    expect(show(removed: true), isFalse);
    expect(show(busy: true), isFalse, reason: 'never over an open question');
    expect(show(last: now.subtract(const Duration(hours: 1))), isFalse);
    expect(show(last: now.subtract(const Duration(hours: 5))), isTrue);
  });
}
