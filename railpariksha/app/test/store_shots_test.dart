// Renders the Play Store / website screenshots from the real screens (Hindi, dark, 360x740 at 3x).
// Skipped unless STORE_SHOTS_DIR is set:  STORE_SHOTS_DIR=/tmp/raw flutter test test/store_shots_test.dart
// pipeline/store_shots.py then frames them with a caption.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/core/app_scope.dart';
import 'package:railpariksha/core/purchases.dart';
import 'package:railpariksha/core/theme.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/logic/quiz_builder.dart';
import 'package:railpariksha/screens/ca_digest_screen.dart';
import 'package:railpariksha/screens/flashcard_screen.dart';
import 'package:railpariksha/screens/practice_screen.dart';
import 'package:railpariksha/screens/pyq_screen.dart';
import 'package:railpariksha/screens/quiz_screen.dart';
import 'package:railpariksha/screens/today_screen.dart';

Future<void> _fonts() async {
  final mukta = FontLoader('Mukta');
  for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    mukta.addFont(Future.value(ByteData.view(File('assets/fonts/Mukta-$w.ttf').readAsBytesSync().buffer)));
  }
  await mukta.load();
  final lora = FontLoader('Lora')
    ..addFont(Future.value(ByteData.view(File('assets/fonts/Lora-Bold.ttf').readAsBytesSync().buffer)));
  await lora.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(
        File('${Platform.environment['FLUTTER_ROOT'] ?? '/tmp/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync().buffer)));
  await icons.load();
  final emoji = FontLoader('NotoColorEmoji')
    ..addFont(Future.value(ByteData.view(File('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf').readAsBytesSync().buffer)));
  await emoji.load();
  final roboto = FontLoader('RobotoShot')
    ..addFont(Future.value(ByteData.view(
        File('${Platform.environment['FLUTTER_ROOT'] ?? '/tmp/flutter'}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf')
            .readAsBytesSync()
            .buffer)));
  await roboto.load();
  final math = FontLoader('MathFallback')
    ..addFont(Future.value(ByteData.view(File('assets/fonts/MathFallback-Regular.ttf').readAsBytesSync().buffer)));
  await math.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = Platform.environment['STORE_SHOTS_DIR'];
  if (dir == null) {
    test('store shots (skipped: STORE_SHOTS_DIR not set)', () {}, skip: true);
    return;
  }
  late ContentRepo repo;
  setUpAll(() async {
    await _fonts();
    repo = ContentRepo();
    await repo.load();
    Directory(dir).createSync(recursive: true);
  });

  Future<void> shot(WidgetTester tester, String name, Widget Function(ContentRepo, Progress) build,
      {Future<void> Function(WidgetTester)? after}) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final p = Progress()
      ..lang = 'hi'
      ..onboarded = true
      ..name = 'Aniket'
      ..examId = 'rrb_ntpc'
      ..removedAds = false
      ..reminders = false;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: AppScope(
        repo: repo,
        progress: p,
        purchases: PurchaseManager(p),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: () {
            final t = buildTheme(Brightness.dark);
            const fb = ['MathFallback', 'RobotoShot', 'NotoColorEmoji'];
            return t.copyWith(
              textTheme: t.textTheme.apply(fontFamilyFallback: fb),
              appBarTheme: t.appBarTheme.copyWith(
                  titleTextStyle: t.appBarTheme.titleTextStyle?.copyWith(fontFamilyFallback: ['Mukta', ...fb])),
            );
          }(),
          home: Scaffold(body: build(repo, p)),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    if (after != null) {
      await after(tester);
      await tester.pump(const Duration(seconds: 2));
    }
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('today', (t) => shot(t, 'today', (r, p) => TodayScreen(onNavigate: (_) {})));
  testWidgets('pyq', (t) => shot(t, 'pyq', (r, p) => const PyqScreen()));
  testWidgets('practice', (t) => shot(t, 'practice', (r, p) => const PracticeScreen()));
  testWidgets('ca', (t) => shot(t, 'ca', (r, p) => const CaDigestScreen()));
  testWidgets(
      'flashcards',
      (t) => shot(t, 'flashcards', (r, p) => const FlashcardScreen(), after: (t) async {
        await t.tap(find.textContaining('टैप'));
        await t.pump(const Duration(seconds: 1));
      }));
  testWidgets(
      'mock',
      (t) => shot(t, 'mock', (r, p) => QuizScreen(spec: QuizBuilder(r, p).mock()), after: (t) async {
        await t.tap(find.byType(CircleAvatar).at(2));
        await t.pump(const Duration(seconds: 1));
      }));
  testWidgets('quiz', (t) {
    late QuizSpec spec;
    return shot(t, 'quiz', (r, p) => QuizScreen(spec: spec = QuizBuilder(r, p).practice(subject: 'maths', topic: 'percentage')),
        after: (t) async {
      // The right answer, so the store picture shows the "correct" state.
      await t.tap(find.byType(CircleAvatar).at(spec.questions.first.answer));
      await t.pump(const Duration(seconds: 1));
    });
  });
}
