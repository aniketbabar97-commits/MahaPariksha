import 'package:flutter/material.dart';

import '../core/app_scope.dart';
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
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: goTo,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.wb_sunny_outlined),
              selectedIcon: const Icon(Icons.wb_sunny),
              label: context.tr('आज', 'Today')),
          NavigationDestination(
              icon: const Icon(Icons.edit_note_outlined),
              selectedIcon: const Icon(Icons.edit_note),
              label: context.tr('सराव', 'Practice')),
          NavigationDestination(
              icon: const Icon(Icons.style_outlined),
              selectedIcon: const Icon(Icons.style),
              label: context.tr('उजळणी', 'Revise')),
          NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: context.tr('प्रगती', 'Progress')),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: context.tr('मी', 'Me')),
        ],
      ),
    );
  }
}
