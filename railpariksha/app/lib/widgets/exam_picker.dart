import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';

class ExamPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;
  const ExamPicker({super.key, this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final repo = context.scope.repo;
    final lang = context.lang;
    return ListView(
      children: [
        for (final g in repo.groups)
          if (repo.exams.any((e) => e.group == g.id)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(g.name.of(lang),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800, color: BrandColors.saffron, letterSpacing: 0.3)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in repo.exams.where((e) => e.group == g.id))
                  ChoiceChip(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      child: Text(e.name.of(lang), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    selected: selected == e.id,
                    selectedColor: BrandColors.saffron.withValues(alpha: 0.25),
                    // The single most important choice in onboarding -- which
                    // exam to prepare for -- had no tactile feedback at all,
                    // unlike every other selection control in the app.
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      onSelected(e.id);
                    },
                  ),
              ],
            ),
          ],
        const SizedBox(height: 24),
      ],
    );
  }
}
