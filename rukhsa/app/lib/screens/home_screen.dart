import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/design_system.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'flashcards_screen.dart';
import 'mind_map_screen.dart';
import 'mock_exam_screen.dart';
import 'quiz_screen.dart';
import 'road_signs_screen.dart';
import 'settings_screen.dart';

const Map<String, String> _emirateLabels = {
  'all': 'All Emirates',
  'dubai': 'Dubai',
  'abu_dhabi': 'Abu Dhabi',
  'sharjah': 'Sharjah',
};

const Map<String, String> _vehicleLabels = {
  'all': 'Any vehicle',
  'car': 'Car',
  'motorcycle': 'Motorcycle',
  'heavy_vehicle': 'Heavy Vehicle',
  'bus': 'Bus',
};

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScopeProvider.of(context);
    final t = AppLocalizations.of(context);
    final bundle = scope.bundle!;
    final lang = scope.lang;
    final filtered = scope.filteredQuestions;

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
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _FilterBar(scope: scope),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  value: '${filtered.length}',
                  label: 'Questions available',
                  icon: Icons.quiz_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatCard(
                  value: '${bundle.categories.length}',
                  label: 'Categories',
                  icon: Icons.category_outlined,
                  color: RukhsaColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Study tools', style: AppType.h2),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.35,
            children: [
              _ToolTile(
                icon: Icons.timer_outlined,
                title: 'Mock Exam',
                subtitle: '35Q · 30 min · pass 23',
                color: RukhsaColors.danger,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MockExamScreen())),
              ),
              _ToolTile(
                icon: Icons.style_outlined,
                title: 'Flashcards',
                subtitle: 'Spaced repetition',
                color: RukhsaColors.success,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FlashcardsScreen())),
              ),
              _ToolTile(
                icon: Icons.signpost_outlined,
                title: 'Road Sign Library',
                subtitle: '${_signCount()} real UAE signs',
                color: RukhsaColors.blue,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoadSignsScreen())),
              ),
              _ToolTile(
                icon: Icons.hub_outlined,
                title: 'Mind Map',
                subtitle: 'How topics connect',
                color: RukhsaColors.goldDark,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MindMapScreen())),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(t.categoriesTitle, style: AppType.h2),
          const SizedBox(height: AppSpacing.sm),
          for (final category in bundle.categories)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: CategoryTile(
                icon: _icons[category.icon] ?? Icons.help_outline,
                title: category.name(lang),
                subtitle: t.questionsCount(filtered.where((q) => q.category == category.id).length),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => QuizScreen(categoryId: category.id)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _signCount() => 20;

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
}

/// Emirate + vehicle-type selectors that filter which question subset (and
/// mock exam / flashcard deck) is served. Backed by [Question.emirate] /
/// [Question.vehicleType], which currently default to "all"/"car" for every
/// question in the bank until per-emirate/vehicle content is authored.
class _FilterBar extends StatelessWidget {
  final AppScope scope;
  const _FilterBar({required this.scope});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _Dropdown(
              icon: Icons.map_outlined,
              value: scope.emirate,
              labels: _emirateLabels,
              options: emirateOptions,
              onChanged: scope.setEmirate,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Dropdown(
              icon: Icons.two_wheeler_outlined,
              value: scope.vehicleType,
              labels: _vehicleLabels,
              options: vehicleTypeOptions,
              onChanged: scope.setVehicleType,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final IconData icon;
  final String value;
  final Map<String, String> labels;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _Dropdown({required this.icon, required this.value, required this.labels, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: value,
        icon: const Icon(Icons.expand_more, size: 18),
        items: [
          for (final o in options)
            DropdownMenuItem(
              value: o,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: RukhsaColors.blue),
                  const SizedBox(width: 6),
                  Flexible(child: Text(labels[o] ?? o, overflow: TextOverflow.ellipsis, style: AppType.caption)),
                ],
              ),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ToolTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppType.h2.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppType.caption.copyWith(color: Theme.of(context).hintColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
