import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';

class ReviseScreen extends StatelessWidget {
  const ReviseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final exam = s.builder.exam;
    if (exam == null) return const SizedBox();
    final lang = context.lang;
    final p = s.progress;
    final cards = s.repo.flashcardsFor(exam);
    final due = s.builder.dueCards(limit: 9999).length;
    final learned = cards.where((c) => (p.cards[c.id]?.reps ?? 0) >= 2).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(context.tr('उजळणी', 'Revise'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(context.tr('स्मार्ट उजळणी: विसरण्याआधीच आठवण!', 'Smart revision: remember before you forget!'),
            style: TextStyle(color: Theme.of(context).hintColor)),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashcardScreen())),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: BrandColors.heroGradient),
              child: Row(children: [
                const Icon(Icons.style, color: BrandColors.sunrise, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('आजची उजळणी', "Today's review"),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    Text(context.tr('$due कार्ड बाकी · $learned/${cards.length} पक्की', '$due due · $learned/${cards.length} mastered'),
                        style: const TextStyle(color: Colors.white70)),
                  ]),
                ),
                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.replay_circle_filled,
          color: BrandColors.wrong,
          title: context.tr('चुकांची वही', 'Mistake book'),
          subtitle: context.tr('${p.mistakes.length} प्रश्न · चुका दुरुस्त होईपर्यंत परत येतील',
              '${p.mistakes.length} questions · they return until you master them'),
          onTap: p.mistakes.isEmpty ? null : () => startQuiz(context, s.builder.mistakes()),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.bookmark,
          color: BrandColors.saffron,
          title: context.tr('जतन केलेले प्रश्न', 'Saved questions'),
          subtitle: context.tr('${p.bookmarks.length} प्रश्न', '${p.bookmarks.length} questions'),
          onTap: p.bookmarks.isEmpty ? null : () => startQuiz(context, s.builder.bookmarked()),
        ),
        SectionTitle(context.tr('विषयानुसार फ्लॅशकार्ड', 'Flashcards by subject')),
        for (final sub in s.repo.subjectsFor(exam))
          if (cards.any((c) => c.subject == sub.id)) ...[
            Card(
              child: ListTile(
                leading: Icon(subjectIcon(sub.icon), color: BrandColors.skyLight),
                title: Text(sub.name.of(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(context.tr('${s.builder.dueCards(subject: sub.id, limit: 9999).length} कार्ड बाकी',
                    '${s.builder.dueCards(subject: sub.id, limit: 9999).length} due')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardScreen(subject: sub.id))),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
