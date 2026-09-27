import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScopeProvider.of(context);
    final t = AppLocalizations.of(context);
    final bundle = scope.bundle!;
    final lang = scope.lang;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: t.settingsTitle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t.categoriesTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final category in bundle.categories)
            _CategoryCard(
              category: category,
              lang: lang,
              questionCount: bundle.byCategory(category.id).length,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QuizScreen(categoryId: category.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final String lang;
  final int questionCount;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.lang,
    required this.questionCount,
    required this.onTap,
  });

  static const Map<String, IconData> _icons = {
    'sign': Icons.signpost_outlined,
    'traffic': Icons.traffic_outlined,
    'speed': Icons.speed_outlined,
    'gavel': Icons.gavel_outlined,
    'highway': Icons.alt_route_outlined,
    'roundabout': Icons.roundabout_left_outlined,
    'parking': Icons.local_parking_outlined,
    'seatbelt': Icons.airline_seat_recline_normal_outlined,
    'no_alcohol': Icons.no_drinks_outlined,
    'document': Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: RukhsaColors.blue.withValues(alpha: 0.1),
                child: Icon(_icons[category.icon] ?? Icons.help_outline, color: RukhsaColors.blue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name(lang),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.questionsCount(questionCount),
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.55), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
