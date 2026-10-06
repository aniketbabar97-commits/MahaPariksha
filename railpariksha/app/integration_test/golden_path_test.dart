// Golden-path end-to-end test: runs the ACTUAL compiled app (not a mocked
// widget tree) on a real device/emulator via `flutter drive`, driving the
// exact flow a brand-new tester takes tomorrow -- onboarding, then every
// bottom-nav tab, then starting a real mock test pulled from the live
// 25k-question bank. Run in --profile mode (the CI workflows' script), which
// on Android builds via the same release Gradle build type as --release (R8
// minification and our proguard-rules.pro both apply) -- `flutter drive`
// itself refuses literal --release for non-web targets since release mode
// strips the VM service the driver needs to talk to the app at all.
//
// This exists because `flutter analyze`/`flutter test` never run the compiled
// app at all, so a release-build-only crash (R8 stripping a class
// androidx.work needed reflectively -- see proguard-rules.pro) sailed
// straight through CI undetected in v1.0.0. This test exercises far more
// real code -- exam/content loading, navigation, the mock-test builder's
// weighted-allocation logic across the full question pool -- than a bare
// launch check, while staying intentionally scoped to flows every tester will
// actually hit, rather than claiming full coverage of every screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:railpariksha/main.dart' as app;
import 'package:railpariksha/widgets/bottom_nav.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var surfaceConverted = false;

  // Best-effort screenshot of the current screen (saved by test_driver/integration_test.dart).
  // Never fails the gate: a screenshot problem is not a build problem.
  Future<void> shot(WidgetTester tester, String name) async {
    try {
      if (!surfaceConverted) {
        await binding.convertFlutterSurfaceToImage();
        surfaceConverted = true;
        await tester.pump();
      }
      await binding.takeScreenshot(name);
    } catch (e) {
      debugPrint('screenshot $name skipped: $e');
    }
  }

  testWidgets('onboarding, all 5 tabs, and a real mock test all load without crashing',
      (tester) async {
    await app.main();
    // Parsing the ~27MB bundled question pack and the first frame both take
    // a moment on a cold start -- settle generously before asserting anything.
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // --- Onboarding: language -> exam -> daily goal ---
    expect(find.byKey(const ValueKey('lang')), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('exam')), findsOneWidget);
    // Pick the first listed exam -- which one doesn't matter for this test.
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pumpAndSettle();

    // Onboarding now inserts a short placement diagnostic between exam-pick
    // and goal-pick (see screens/onboarding.dart) -- skip it here since this
    // test is about the golden path loading without crashing, not the
    // diagnostic's own scoring logic.
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('goal')), findsOneWidget);
    await tester.tap(find.text("Let's go!"));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // --- Home shell: should now show the 5-tab floating bottom nav ---
    // RpBottomNav replaced the stock NavigationBar/NavigationDestination
    // widgets this test used to find tabs by type -- each tab button now
    // carries a stable ValueKey('nav_tab_$i') instead (see widgets/bottom_nav.dart).
    expect(find.byType(RpBottomNav), findsOneWidget);
    Finder tab(int i) => find.byKey(ValueKey('nav_tab_$i'));
    for (var i = 0; i < 5; i++) {
      expect(tab(i), findsOneWidget);
    }

    // Visit every tab once -- each one builds its own screen from the loaded
    // content/progress state, so this alone catches a per-tab render crash.
    for (var i = 0; i < 5; i++) {
      await tester.tap(tab(i));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'tab $i threw while rendering');
      await shot(tester, 'tab_$i');
    }

    // --- Start a real mock test (exercises QuizBuilder.mock() against the
    // full live question bank: weighted subject allocation, pool filtering,
    // everything) ---
    await tester.tap(tab(1)); // Practice tab
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.textContaining('Mock test'));
    // NOT pumpAndSettle: QuizScreen starts a Timer.periodic(1s) countdown for
    // the exam's time limit (tens of minutes), which keeps scheduling new
    // frames for its entire duration -- pumpAndSettle waits for frames to stop
    // being scheduled at all, so it never returns and the job hangs until
    // GitHub's job timeout kills it (confirmed via an actual run: the step sat
    // for ~6 hours before being force-cancelled). A few fixed pumps are enough
    // to let the quiz screen finish building and surface any render exception.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull, reason: 'mock test crashed on start');
    await shot(tester, 'mock_quiz');

    // A mock test screen has no bottom nav (it's pushed full-screen) -- its
    // absence confirms we actually navigated into the quiz, not that the tap
    // silently no-opped.
    expect(find.byType(RpBottomNav), findsNothing);
  });
}
