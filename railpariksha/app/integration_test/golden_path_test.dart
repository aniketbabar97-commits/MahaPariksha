// Golden-path end-to-end test: runs the ACTUAL compiled app (not a mocked
// widget tree) on a real device/emulator, driving the exact flow a brand-new
// tester takes tomorrow -- onboarding, then every bottom-nav tab, then
// starting a real mock test pulled from the live 25k-question bank.
//
// This exists because `flutter analyze`/`flutter test` never run the compiled
// app at all, so a release-build-only crash (see pipeline/smoke_test.sh's
// comment) sailed straight through CI undetected. This test exercises far
// more real code -- exam/content loading, navigation, the mock-test builder's
// weighted-allocation logic across the full question pool -- than a bare
// launch check, while staying intentionally scoped to flows every tester will
// actually hit, rather than claiming full coverage of every screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:railpariksha/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

    expect(find.byKey(const ValueKey('goal')), findsOneWidget);
    await tester.tap(find.text("Let's go!"));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // --- Home shell: should now show the 5-tab bottom nav ---
    expect(find.byType(NavigationBar), findsOneWidget);
    final tabs = find.byType(NavigationDestination);
    expect(tabs, findsNWidgets(5));

    // Visit every tab once -- each one builds its own screen from the loaded
    // content/progress state, so this alone catches a per-tab render crash.
    for (var i = 0; i < 5; i++) {
      await tester.tap(tabs.at(i));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'tab $i threw while rendering');
    }

    // --- Start a real mock test (exercises QuizBuilder.mock() against the
    // full live question bank: weighted subject allocation, pool filtering,
    // everything) ---
    await tester.tap(tabs.at(1)); // Practice tab
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.textContaining('Mock test'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(tester.takeException(), isNull, reason: 'mock test crashed on start');

    // A mock test screen has no bottom nav (it's pushed full-screen) -- its
    // absence confirms we actually navigated into the quiz, not that the tap
    // silently no-opped.
    expect(find.byType(NavigationBar), findsNothing);
  });
}
