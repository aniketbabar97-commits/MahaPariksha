import 'package:flutter/material.dart';

import '../core/app_scope.dart';
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

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  void goTo(int i) => setState(() => index = i);

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
      NavItem(Icons.edit_note_outlined, Icons.edit_note, context.tr('सराव', 'Practice')),
      NavItem(Icons.style_outlined, Icons.style, context.tr('उजळणी', 'Revise')),
      NavItem(Icons.insights_outlined, Icons.insights, context.tr('प्रगती', 'Progress')),
      NavItem(Icons.person_outline, Icons.person, context.tr('मी', 'Me')),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: BharariBottomNav(index: index, items: items, onTap: goTo),
    );
  }
}
