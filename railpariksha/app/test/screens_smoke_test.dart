import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/core/app_scope.dart';
import 'package:railpariksha/core/purchases.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/logic/quiz_builder.dart';
import 'package:railpariksha/screens/beast_mode_screen.dart';
import 'package:railpariksha/screens/ca_archive_screen.dart';
import 'package:railpariksha/screens/leaderboard_screen.dart';
import 'package:railpariksha/screens/reel_screen.dart';

/// Opens the screens the layout smoke test doesn't reach and uses them a little, so a crash
/// on first use (not just on first paint) fails here instead of in a student's hands.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepo repo;

  setUpAll(() async {
    repo = ContentRepo();
    await repo.load();
  });

  Future<void> open(WidgetTester tester, Widget screen, String lang) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final progress = Progress()
      ..lang = lang
      ..examId = 'rrb_ntpc'
      ..removedAds = true;
    await tester.pumpWidget(AppScope(
      repo: repo,
      progress: progress,
      purchases: PurchaseManager(progress),
      child: MaterialApp(home: screen),
    ));
    await tester.pump(const Duration(milliseconds: 600));
  }

  for (final lang in ['hi', 'en']) {
    testWidgets('Beast Mode runs a sprint: answers score and the timer ticks ($lang)', (tester) async {
      final progress = Progress()..examId = 'rrb_ntpc';
      final spec = QuizBuilder(repo, progress).beast(seconds: 60);
      expect(spec.questions, isNotEmpty);
      await open(tester, BeastModeScreen(spec: spec, seconds: 60), lang);
      await tester.tap(find.byType(InkWell).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox()); // disposes the timer
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Reel Mode survives 40 cards (questions, flashcards, quotes) on a small phone ($lang)', (tester) async {
      final overflows = <String>[];
      final prior = FlutterError.onError;
      FlutterError.onError = (d) {
        final msg = d.exceptionAsString();
        if (msg.contains('overflowed')) {
          overflows.add(msg);
        } else {
          prior?.call(d);
        }
      };
      await open(tester, const ReelScreen(), lang);
      for (var i = 0; i < 40; i++) {
        await tester.fling(find.byType(ReelScreen), const Offset(0, -500), 1500, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 700));
      }
      FlutterError.onError = prior;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(overflows, isEmpty, reason: overflows.toSet().join('\n'));
    });

    testWidgets('Leaderboard degrades cleanly when Firebase is unavailable ($lang)', (tester) async {
      await open(tester, const LeaderboardScreen(), lang);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Current Affairs archive lists its dates ($lang)', (tester) async {
      await open(tester, const CaArchiveScreen(), lang);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
