// Renders every main screen at a budget-phone size, in both languages and at
// the largest text scale the app allows, with the app's real Mukta font so
// text widths match devices. Any RenderFlex overflow fails the test, naming
// the screen and the offending widget.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/core/app_scope.dart';
import 'package:railpariksha/core/purchases.dart';
import 'package:railpariksha/core/theme.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/logic/quiz_builder.dart';
import 'package:railpariksha/screens/ca_digest_screen.dart';
import 'package:railpariksha/screens/cheat_sheet_screen.dart';
import 'package:railpariksha/screens/exam_strategy_screen.dart';
import 'package:railpariksha/screens/flashcard_screen.dart';
import 'package:railpariksha/screens/gk_booster_screen.dart';
import 'package:railpariksha/screens/me_screen.dart';
import 'package:railpariksha/screens/practice_screen.dart';
import 'package:railpariksha/screens/progress_screen.dart';
import 'package:railpariksha/screens/quiz_screen.dart';
import 'package:railpariksha/screens/results_screen.dart';
import 'package:railpariksha/screens/revise_screen.dart';
import 'package:railpariksha/screens/revision_plan_screen.dart';
import 'package:railpariksha/screens/search_screen.dart';
import 'package:railpariksha/screens/today_screen.dart';
import 'package:railpariksha/screens/topic_screen.dart';

Future<void> _loadMukta() async {
  final loader = FontLoader('Mukta');
  for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Mukta-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
  // English headlines (app-bar titles) use Lora; without it the test font draws solid blocks.
  final lora = FontLoader('Lora')
    ..addFont(Future.value(ByteData.view(File('assets/fonts/Lora-Bold.ttf').readAsBytesSync().buffer)));
  await lora.load();
}

/// An active learner: exam chosen, history across subjects, a mock taken,
/// a streak going -- so conditional cards (weak spots, pacing, mocks) render.
Progress _freshUser(ContentRepo repo, String lang) => Progress()
  ..lang = lang
  ..onboarded = true
  ..examId = 'rrb_group_d'
  ..removedAds = true
  ..reminders = false;

Progress _activeLearner(ContentRepo repo, String lang) {
  final p = Progress()
    ..lang = lang
    ..onboarded = true
    ..name = 'Aniket'
    ..examId = 'rrb_ntpc'
    ..removedAds = true
    ..reminders = false
    ..streak = 12
    ..bestStreak = 30
    ..xp = 4321
    ..examDate = DateTime.now().add(const Duration(days: 45));
  var i = 0;
  for (final q in repo.questionsFor(repo.exam('rrb_ntpc')!).take(300)) {
    p.qStats[q.id] = [2, i % 3 == 0 ? 0 : 2, i % 3 == 0 ? 0 : 1];
    i++;
  }
  p.mocks.add(MockResult(today(), 'rrb_ntpc', 61.33, 100));
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepo repo;

  setUpAll(() async {
    await _loadMukta();
    repo = ContentRepo();
    await repo.load();
  });

  final screens = <String, Widget Function(ContentRepo repo, Progress p)>{
    'Today': (r, p) => TodayScreen(onNavigate: (_) {}),
    'Practice': (r, p) => const PracticeScreen(),
    'Subject': (r, p) => SubjectScreen(subject: r.subject('maths')!),
    'Topic': (r, p) => TopicScreen(subject: r.subject('maths')!, topic: r.topic('maths', 'percentage')!),
    'Revise': (r, p) => const ReviseScreen(),
    'Progress': (r, p) => const ProgressScreen(),
    'Me': (r, p) => const MeScreen(),
    'Search': (r, p) => const SearchScreen(),
    'Flashcards': (r, p) => const FlashcardScreen(),
    'Revision plan': (r, p) => const RevisionPlanScreen(),
    'GK booster': (r, p) => const GkBoosterScreen(),
    'CA digest': (r, p) => const CaDigestScreen(),
    'Cheat sheet': (r, p) => CheatSheetScreen(subject: r.subject('maths')!),
    'Exam strategy': (r, p) => ExamStrategyScreen(exam: r.exam('rrb_ntpc')!),
    'Quiz (practice)': (r, p) => QuizScreen(spec: QuizBuilder(r, p).practice(subject: 'maths', topic: 'percentage')),
    'Quiz (mock)': (r, p) => QuizScreen(spec: QuizBuilder(r, p).mock()),
    'Results (mock)': (r, p) {
      final spec = QuizBuilder(r, p).mock();
      return ResultsScreen(
        spec: spec,
        answers: [for (var i = 0; i < spec.questions.length; i++) i % 4 == 0 ? null : i % 3],
        xpEarned: 120,
        elapsed: const Duration(minutes: 18, seconds: 7),
        speedScore: 0,
        timePerQuestion: [for (var i = 0; i < spec.questions.length; i++) Duration(seconds: 10 + (i * 7) % 90)],
      );
    },
  };

  for (final lang in ['hi', 'en']) {
    for (final scale in [1.0, 1.3]) {
      for (final (entry, fresh) in [
        for (final e in screens.entries) (e, false),
        for (final e in screens.entries.where((e) => const {'Today', 'Progress', 'Me', 'Practice'}.contains(e.key))) (e, true),
      ]) {
        testWidgets('${entry.key}${fresh ? ' (new user)' : ''} fits a 360dp phone ($lang, text x$scale)', (tester) async {
          tester.view.physicalSize = const Size(360 * 3, 740 * 3);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);

          final overflows = <String>[];
          final prior = FlutterError.onError;
          FlutterError.onError = (details) {
            final msg = details.exceptionAsString();
            if (msg.contains('overflowed')) {
              overflows.add('$msg\n${details.context?.toDescription() ?? ''}\n'
                  '${details.informationCollector?.call().take(2).join('\n') ?? ''}');
            } else {
              prior?.call(details);
            }
          };

          final p = fresh ? _freshUser(repo, lang) : _activeLearner(repo, lang);
          await tester.pumpWidget(AppScope(
            repo: repo,
            progress: p,
            purchases: PurchaseManager(p),
            child: MaterialApp(
              theme: buildTheme(Brightness.light),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(body: entry.value(repo, p)),
            ),
          ));
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          FlutterError.onError = prior;
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));

          expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
        });
      }
    }
  }
}
