import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/reminders.dart';
import '../widgets/bottom_nav.dart';
import 'me_screen.dart';
import 'practice_screen.dart';
import 'progress_screen.dart';
import 'revise_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int index = 0;

  void goTo(int i) => setState(() => index = i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back to the foreground is the other moment (besides the activity
  // hook in main.dart) a stale schedule can be caught and fixed: the day may
  // have rolled over, or the user may have practiced in a widget/other entry
  // point, while the app sat backgrounded. Re-running applyReminders here
  // cancels and re-picks all four notification slots off current state --
  // see the staleness note in reminders.dart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final p = context.scope.progress;
      if (p.reminders) applyReminders(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(onNavigate: goTo),
      const PracticeScreen(),
      const ReviseScreen(),
      const ProgressScreen(),
      const MeScreen(),
    ];
    final items = [
      NavItem(Icons.wb_sunny_outlined, Icons.wb_sunny, context.tr('आज', 'Today')),
      NavItem(Icons.edit_note_outlined, Icons.edit_note, context.tr('अभ्यास', 'Practice')),
      NavItem(Icons.style_outlined, Icons.style, context.tr('रिवीज़न', 'Revise')),
      NavItem(Icons.insights_outlined, Icons.insights, context.tr('प्रगति', 'Progress')),
      NavItem(Icons.person_outline, Icons.person, context.tr('मैं', 'Me')),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: RpBottomNav(index: index, items: items, onTap: goTo),
    );
  }
}
