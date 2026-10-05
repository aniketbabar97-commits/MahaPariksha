// The full validation matrix. Every screen is rendered with the app's real Mukta font and theme:
//   * overflow: light + dark, three phone widths (320/360/412 dp), three text scales (the app
//     clamps system text to 0.85-1.3, see main.dart), Hindi + English -- any RenderFlex overflow fails;
//   * contrast: light + dark, both languages -- Flutter's textContrastGuideline (WCAG AA) is run
//     on every rendered screen.
// Ads are left ON (removedAds=false): with no ads plugin in tests the slots collapse, but a screen
// that depends on one being absent would show up here.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/core/app_scope.dart';
import 'package:railpariksha/core/purchases.dart';
import 'package:railpariksha/core/theme.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/data/pyq_repo.dart';
import 'package:railpariksha/logic/quiz_builder.dart';
import 'package:railpariksha/screens/beast_mode_screen.dart';
import 'package:railpariksha/screens/ca_archive_screen.dart';
import 'package:railpariksha/screens/ca_digest_screen.dart';
import 'package:railpariksha/screens/cheat_sheet_screen.dart';
import 'package:railpariksha/screens/exam_strategy_screen.dart';
import 'package:railpariksha/screens/flashcard_screen.dart';
import 'package:railpariksha/screens/gk_booster_screen.dart';
import 'package:railpariksha/screens/leaderboard_screen.dart';
import 'package:railpariksha/screens/me_screen.dart';
import 'package:railpariksha/screens/onboarding.dart';
import 'package:railpariksha/screens/practice_screen.dart';
import 'package:railpariksha/screens/progress_screen.dart';
import 'package:railpariksha/screens/pyq_screen.dart';
import 'package:railpariksha/screens/quiz_screen.dart';
import 'package:railpariksha/screens/results_screen.dart';
import 'package:railpariksha/screens/revise_screen.dart';
import 'package:railpariksha/screens/revision_plan_screen.dart';
import 'package:railpariksha/screens/search_screen.dart';
import 'package:railpariksha/screens/today_screen.dart';
import 'package:railpariksha/screens/topic_screen.dart';

import 'contrast_check.dart';

Future<void> _loadMukta() async {
  final loader = FontLoader('Mukta');
  for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Mukta-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Progress _learner(String lang, {bool fresh = false}) {
  final p = Progress()
    ..lang = lang
    ..onboarded = true
    ..name = 'Aniket'
    ..examId = 'rrb_ntpc'
    ..removedAds = false
    ..reminders = false;
  if (!fresh) {
    p
      ..streak = 12
      ..bestStreak = 30
      ..xp = 4321
      ..examDate = DateTime.now().add(const Duration(days: 45));
  }
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepo repo;
  late List<PyqSet> pyqSets;

  setUpAll(() async {
    await _loadMukta();
    repo = ContentRepo();
    await repo.load();
    pyqSets = (await pyqRepo.sets());
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
    'CA archive': (r, p) => const CaArchiveScreen(),
    'Cheat sheet': (r, p) => CheatSheetScreen(subject: r.subject('maths')!),
    'Exam strategy': (r, p) => ExamStrategyScreen(exam: r.exam('rrb_ntpc')!),
    'Leaderboard': (r, p) => const LeaderboardScreen(),
    'Onboarding': (r, p) => const OnboardingScreen(),
    'PYQ': (r, p) => const PyqScreen(),
    'PYQ paper': (r, p) => PyqSetScreen(set: pyqSets.firstWhere((s) => s.railway)),
    'Quiz (practice)': (r, p) => QuizScreen(spec: QuizBuilder(r, p).practice(subject: 'maths', topic: 'percentage')),
    'Quiz (mock)': (r, p) => QuizScreen(spec: QuizBuilder(r, p).mock()),
    'Beast Mode': (r, p) => BeastModeScreen(spec: QuizBuilder(r, p).beast(seconds: 60), seconds: 60),
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

  Future<void> show(WidgetTester tester, Widget Function(ContentRepo, Progress) build,
      {required String lang, required Brightness brightness, required double width, double scale = 1.0, bool fresh = false, GlobalKey? boundary}) async {
    tester.view.physicalSize = Size(width * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final p = _learner(lang, fresh: fresh);
    final app = AppScope(
      repo: repo,
      progress: p,
      purchases: PurchaseManager(p),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: build(repo, p)),
      ),
    );
    await tester.pumpWidget(boundary == null ? app : RepaintBoundary(key: boundary, child: app));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  // ---- overflow matrix ----
  for (final lang in ['hi', 'en']) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [0.85, 1.0, 1.3]) {
          for (final e in screens.entries) {
            testWidgets('overflow: ${e.key} ($lang ${brightness.name} ${width.toInt()}dp x$scale)', (tester) async {
              final overflows = <String>[];
              final prior = FlutterError.onError;
              FlutterError.onError = (d) {
                final msg = d.exceptionAsString();
                if (msg.contains('overflowed')) {
                  overflows.add('$msg\n${d.context?.toDescription() ?? ''}\n${d.informationCollector?.call().take(2).join('\n') ?? ''}');
                } else {
                  prior?.call(d);
                }
              };
              await show(tester, e.value, lang: lang, brightness: brightness, width: width, scale: scale);
              FlutterError.onError = prior;
              await tester.pumpWidget(const SizedBox());
              await tester.pump(const Duration(seconds: 2));
              expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
            });
          }
        }
      }
    }
  }

  // ---- contrast ----
  for (final lang in ['hi', 'en']) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final e in screens.entries) {
        testWidgets('contrast: ${e.key} ($lang ${brightness.name})', (tester) async {
          final key = GlobalKey();
          await show(tester, e.value, lang: lang, brightness: brightness, width: 360, boundary: key);
          final shots = Platform.environment['SHOT_DIR'];
          final findings = await contrastFindings(tester, key,
              savePng: shots == null ? null : '$shots/${e.key.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${lang}_${brightness.name}.png');
          final sink = Platform.environment['CONTRAST_OUT'];
          if (sink != null && findings.isNotEmpty) {
            File(sink).writeAsStringSync(findings.map((f) => '${e.key} ($lang ${brightness.name}) :: $f\n').join(), mode: FileMode.append);
          }
          expect(findings, isEmpty, reason: '\n${findings.join('\n')}');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });
      }
    }
  }
}
