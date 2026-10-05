import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../widgets/common.dart';
import 'cheat_sheet_screen.dart';
import 'flashcard_screen.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';
import '../core/ads.dart';

class ReviseScreen extends StatelessWidget {
  const ReviseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final exam = s.builder.exam;
    if (exam == null) return const NoExamState();
    final lang = context.lang;
    final p = s.progress;
    final cards = s.repo.flashcardsFor(exam);
    final due = s.builder.dueCards(limit: 9999).length;
    final learned = cards.where((c) => (p.cards[c.id]?.reps ?? 0) >= 2).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(context.tr('रिवीज़न 🔁', 'Revise 🔁'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(context.tr('स्मार्ट रिवीज़न: भूलने से पहले याद करें! 🧠✨', 'Smart revision: remember before you forget! 🧠✨'),
            style: TextStyle(color: Theme.of(context).hintColor)),
        const SizedBox(height: 16),
        TapScale(
          child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              push(context, (_) => const FlashcardScreen());
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: BrandColors.heroGradient),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.style, color: BrandColors.sunrise, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.tr('आज का रिवीज़न 🌤️', "Today's review 🌤️"),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      Text(context.tr('$due कार्ड बाकी · $learned/${cards.length} पक्के', '$due due · $learned/${cards.length} mastered'),
                          style: const TextStyle(color: BrandColors.onGradientMuted)),
                    ]),
                  ),
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                ]),
                if (cards.isNotEmpty) ...[
                  const SizedBox(height: Spacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: learned / cards.length),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 7,
                        backgroundColor: Colors.white24,
                        color: BrandColors.sunrise,
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
          ),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.replay_circle_filled,
          color: BrandColors.wrong,
          title: context.tr('गलतियों की कॉपी', 'Mistake book'),
          subtitle: context.tr('${p.mistakes.length} प्रश्न · जब तक सही न हों, बार-बार आएंगे',
              '${p.mistakes.length} questions · they return until you master them'),
          onTap: p.mistakes.isEmpty ? null : () => startQuiz(context, s.builder.mistakes()),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.bookmark,
          color: BrandColors.saffron,
          title: context.tr('सहेजे गए प्रश्न', 'Saved questions'),
          subtitle: context.tr('${p.bookmarks.length} प्रश्न', '${p.bookmarks.length} questions'),
          onTap: p.bookmarks.isEmpty ? null : () => startQuiz(context, s.builder.bookmarked()),
        ),
        if (s.repo.subjectsFor(exam).any((sub) => s.repo.hasNotes(sub.id))) ...[
          SectionTitle(context.tr('नोट्स व माइंड मैप 🧠🗺️', 'Notes & mind maps 🧠🗺️')),
          SizedBox(
            height: _tileRowHeight(context),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final sub in s.repo.subjectsFor(exam).where((sub) => s.repo.hasNotes(sub.id)))
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 120,
                      child: TapScale(
                        child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            push(context, (_) => SubjectScreen(subject: sub));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(subjectIcon(sub.icon), color: BrandColors.readable(context, BrandColors.saffron, min: 3), size: 30),
                              const SizedBox(height: 6),
                              Text(sub.name.of(lang),
                                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ]),
                          ),
                        ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (s.repo.subjectsFor(exam).any((sub) => s.repo.hasCheatSheets(sub.id))) ...[
          SectionTitle(context.tr('चीट शीट ⚡', 'Cheat sheets ⚡')),
          SizedBox(
            height: _tileRowHeight(context),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final sub in s.repo.subjectsFor(exam).where((sub) => s.repo.hasCheatSheets(sub.id)))
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 120,
                      child: TapScale(
                        child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            push(context, (_) => CheatSheetScreen(subject: sub));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.bolt, color: BrandColors.readable(context, BrandColors.saffron, min: 3), size: 30),
                              const SizedBox(height: 6),
                              Text(sub.name.of(lang),
                                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ]),
                          ),
                        ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        SectionTitle(context.tr('विषयवार फ्लैशकार्ड 🎴', 'Flashcards by subject 🎴')),
        for (final sub in s.repo.subjectsFor(exam))
          if (cards.any((c) => c.subject == sub.id)) ...[
            Card(
              child: ListTile(
                leading: Icon(subjectIcon(sub.icon), color: BrandColors.skyLight),
                title: Text(sub.name.of(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(context.tr('${s.builder.dueCards(subject: sub.id, limit: 9999).length} कार्ड बाकी',
                    '${s.builder.dueCards(subject: sub.id, limit: 9999).length} due')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  HapticFeedback.selectionClick();
                  push(context, (_) => FlashcardScreen(subject: sub.id));
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
              const AdSlot(),
      ],
    );
  }
}

/// Height for the horizontal subject-tile rows: 104 at default text size,
/// growing with the user's text scale so a two-line name never clips.
double _tileRowHeight(BuildContext context) => 104 + (MediaQuery.textScalerOf(context).scale(13) - 13) * 2 * 1.8;
