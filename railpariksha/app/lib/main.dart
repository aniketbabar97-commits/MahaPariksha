import 'dart:async';

import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/ads.dart';
import 'logic/progress_backup.dart';
import 'core/app_scope.dart';
import 'core/notifications.dart';
import 'core/purchases.dart';
import 'core/reminders.dart';
import 'core/theme.dart';
import 'data/content_repo.dart';
import 'data/progress.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // The leaderboard is an optional extra, never a launch blocker: this app is
  // offline-first by design, so a missing/misconfigured Firebase project (or
  // simply no network at startup) must never stop the app from opening.
  try {
    await Firebase.initializeApp();
    // Crash reports: Flutter errors and anything uncaught on the platform side go to Crashlytics so
    // Play's "Android vitals" never surprise us. Release builds only; debug stays on the console.
    if (kReleaseMode) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (_) {
    // LeaderboardService checks Firebase.apps before every call, so the
    // leaderboard UI just shows its "unavailable" state instead of throwing.
  }
  final repo = ContentRepo();
  final progress = Progress();
  await Future.wait([repo.load(), progress.load()]);
  // Reschedule the moment today's streak is actually saved, so a late-night
  // streak-SOS already queued for tonight (scheduled from a stale snapshot
  // taken at an earlier launch) gets cancelled right away instead of firing
  // after the streak no longer needs saving. See reminders.dart for the rest
  // of the staleness story this is covering.
  progress.onActiveToday = () {
    if (progress.reminders) applyReminders(progress);
  };
  if (progress.examId != null && repo.exam(progress.examId!) == null) {
    progress.examId = null;
    progress.onboarded = false;
  }
  final purchases = PurchaseManager(progress);
  runApp(AppScope(repo: repo, progress: progress, purchases: purchases, child: const RailParikshaApp()));
  repo.checkForUpdate();
  repo.checkCaFeed();
  ProgressBackup.uploadIfDue(progress);
  initAds();
  AppOpenAdManager.start(progress);
  // Fire-and-forget: a slow/unavailable Play Billing connection must never
  // delay startup. removedAds is already loaded from disk by progress.load()
  // above, so ads stay off for a paying user even before this resolves.
  unawaited(purchases.init());
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
          // The in-app size (Me > Text size) multiplies the phone's setting; the result stays inside
          // the same 0.85-1.3 band every layout is tested against.
          textScaler: TextScaler.linear(
              (MediaQuery.textScalerOf(context).scale(1) * p.textBoost).clamp(0.85, 1.3)),
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
