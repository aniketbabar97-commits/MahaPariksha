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
      home: p.onboarded ? const HomeShell() : const OnboardingScreen(),
    );
  }
}
