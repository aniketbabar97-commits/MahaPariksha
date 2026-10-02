import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/ads.dart';
import 'core/app_scope.dart';
import 'core/notifications.dart';
import 'core/reminders.dart';
import 'core/theme.dart';
import 'data/content_repo.dart';
import 'data/progress.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final repo = ContentRepo();
  final progress = Progress();
  await Future.wait([repo.load(), progress.load()]);
  if (progress.examId != null && repo.exam(progress.examId!) == null) {
    progress.examId = null;
    progress.onboarded = false;
  }
  runApp(AppScope(repo: repo, progress: progress, child: const RailParikshaApp()));
  repo.checkForUpdate();
  initAds();
  await RailParikshaNotifications.init();
  if (progress.reminders) await applyReminders(progress);
}

class RailParikshaApp extends StatelessWidget {
  const RailParikshaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.scope.progress;
    return MaterialApp(
      title: 'RailPariksha',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (p.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      // Clamp system text scaling -- the card/row-based layouts throughout this
      // app (headers, chips, nav bar labels) assume roughly phone-default text
      // size. An uncapped scaler (some OEM "large font"/"display size"
      // accessibility settings go well past 2x) makes even single characters
      // wider than their row, so Flutter wraps every letter onto its own line.
      // Still respects the user's preference, just keeps it from breaking layout.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3),
        ),
        child: child!,
      ),
      // Finishing onboarding -- the single most emotionally important moment
      // in the app -- used to be an instant, unanimated hard cut (MaterialApp
      // just swapping `home`), less motion polish than switching a quiz
      // question. An AnimatedSwitcher here guarantees a transition regardless
      // of how MaterialApp/Navigator internally handles a changed `home`, and
      // matches RpRevealRoute's fade+scale "curtain opening" feel.
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        switchInCurve: Curves.easeOutQuart,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation), child: child),
        ),
        child: p.onboarded ? const HomeShell(key: ValueKey('home')) : const OnboardingScreen(key: ValueKey('onboarding')),
      ),
    );
  }
}
