import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/exam_picker.dart';
import 'cheat_sheet_screen.dart';
import 'pyq_screen.dart';
import 'quiz_screen.dart';
import 'topic_screen.dart';
import '../core/format.dart';

Future<void> showExamSwitcher(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ExamPicker(
            selected: ctx.scope.progress.examId,
            onSelected: (id) {
              ctx.scope.progress.update((p) => p.examId = id);
              Navigator.pop(ctx);
            },
          ),
        ),
      ),
    );

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final exam = s.builder.exam;
    final lang = context.lang;
    if (exam == null) return const NoExamState();
    final subjects = s.repo.subjectsFor(exam);
    final stats = s.builder.subjectStats();
    final pool = s.repo.questionsFor(exam);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(children: [
          Expanded(
            child: Text(context.tr('अभ्यास 📝', 'Practice 📝'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: ActionChip(
              avatar: const Icon(Icons.swap_horiz, size: 18),
              label: Text(exam.name.of(lang), maxLines: 1, overflow: TextOverflow.ellipsis),
              onPressed: () => showExamSwitcher(context),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(context.tr('${fmtCount(pool.length)} प्रश्न · ${subjects.length} विषय', '${fmtCount(pool.length)} questions · ${subjects.length} subjects'),
            style: TextStyle(color: Theme.of(context).hintColor)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: _QuickTile(
              icon: Icons.assignment,
              color: BrandColors.sky,
              label: context.tr('मॉक टेस्ट 🏆', 'Mock test 🏆'),
              onTap: () => startQuiz(context, s.builder.mock()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickTile(
              icon: Icons.timer,
              color: BrandColors.correct,
              label: context.tr('स्पीड राउंड ⚡', 'Speed round ⚡'),
              onTap: () => startQuiz(context, s.builder.speed()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickTile(
              icon: Icons.bookmark,
              color: BrandColors.saffron,
              label: context.tr('सहेजे गए 🔖', 'Saved 🔖'),
              onTap: () => startQuiz(context, s.builder.bookmarked()),
            ),
          ),
        ]),
        if (exam.paperQuestions != null) ...[
          const SizedBox(height: 10),
          ActionCard(
            icon: Icons.fact_check,
            color: BrandColors.saffron,
            title: context.tr('फुल-लेंथ मॉक 🎯', 'Full-length mock 🎯'),
            subtitle: context.tr(
                '${exam.paperQuestions} प्रश्न · ${exam.paperMinutes} मिनट · असली परीक्षा पैटर्न',
                '${exam.paperQuestions} questions · ${exam.paperMinutes} minutes · real exam pattern'),
            onTap: () => startQuiz(context, s.builder.mock(full: true)),
          ),
        ],
        const SizedBox(height: 10),
        ActionCard(
          icon: Icons.history_edu,
          color: BrandColors.correct,
          title: context.tr('पिछले वर्ष के प्रश्न (PYQ) 📜', 'Previous year questions (PYQ) 📜'),
          subtitle: context.tr('RRB व RPF के 45,000+ आधिकारिक प्रश्न · पूरे प्रश्नपत्र हल करें',
              '45,000+ official RRB & RPF questions · attempt full papers'),
          onTap: () => push(context, (_) => const PyqScreen()),
        ),
        SectionTitle(context.tr('विषयवार अभ्यास 📚', 'Practice by subject 📚')),
        for (final sub in subjects) ...[
          _SubjectTile(
            subject: sub,
            count: pool.where((q) => q.subject == sub.id).length,
            stat: stats[sub.id],
          ),
          const SizedBox(height: 10),
        ],
        if (s.repo.subject('english') != null) ...[
          SectionTitle(context.tr('बोनस अभ्यास 🎁', 'Bonus practice 🎁')),
          _EnglishBonusTile(),
        ],
        if (!s.progress.removedAds) const Center(child: AdBanner()),
      ],
    );
  }
}

/// English is not part of any RRB/RPF exam's official CBT syllabus, so it is deliberately not
/// attached to any exam's subject list. It is offered here as always-visible bonus practice for
/// aspirants who also prepare for exams (SSC, banking) that do test English.
class _EnglishBonusTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sub = context.scope.repo.subject('english');
    if (sub == null) return const SizedBox();
    final count = context.scope.repo.questionsInSubject('english').length;
    return ActionCard(
      icon: subjectIcon(sub.icon),
      color: BrandColors.correct,
      title: sub.name.of(context.lang),
      subtitle: context.tr('${fmtCount(count)} प्रश्न · परीक्षा के पाठ्यक्रम का हिस्सा नहीं, बोनस अभ्यास',
          '${fmtCount(count)} questions · not part of the exam syllabus, bonus practice'),
      onTap: () => push(context, (_) => SubjectScreen(subject: sub)),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => TapScale(
        child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
        ),
      );
}

class _SubjectTile extends StatelessWidget {
  final Subject subject;
  final int count;
  final List<int>? stat;
  const _SubjectTile({required this.subject, required this.count, this.stat});

  @override
  Widget build(BuildContext context) {
    final acc = stat == null || stat![0] == 0 ? null : stat![1] / stat![0];
    return ActionCard(
      icon: subjectIcon(subject.icon),
      color: BrandColors.skyLight,
      title: subject.name.of(context.lang),
      subtitle: acc == null
          ? context.tr('${fmtCount(count)} प्रश्न · शुरू करें', '${fmtCount(count)} questions · start now')
          : context.tr('${fmtCount(count)} प्रश्न · अचूकता ${(acc * 100).round()}%', '${fmtCount(count)} questions · ${(acc * 100).round()}% accuracy'),
      onTap: () => push(context, (_) => SubjectScreen(subject: subject)),
    );
  }
}

class SubjectScreen extends StatelessWidget {
  final Subject subject;
  const SubjectScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final lang = context.lang;
    final topicStats = {for (final t in s.builder.topicStats().where((t) => t.subject == subject.id)) t.topic: t};
    return Scaffold(
      appBar: AppBar(title: Text(subject.name.of(lang))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: BrandColors.saffron),
            icon: const Icon(Icons.shuffle),
            label: Text(context.tr('सभी टॉपिक से मिश्रित अभ्यास 🔀', 'Mixed practice from all topics 🔀')),
            onPressed: () {
              HapticFeedback.selectionClick();
              startQuiz(context, s.builder.practice(subject: subject.id));
            },
          ),
          if (s.repo.hasCheatSheets(subject.id)) ...[
            const SizedBox(height: Spacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.bolt, color: BrandColors.saffron),
              label: Text(context.tr('चीट शीट देखें ⚡', 'View cheat sheet ⚡')),
              onPressed: () {
                HapticFeedback.selectionClick();
                push(context, (_) => CheatSheetScreen(subject: subject));
              },
            ),
          ],
          SectionTitle(context.tr('टॉपिक 🧩', 'Topics 🧩')),
          for (final t in subject.topics) ...[
            Builder(builder: (context) {
              final n = s.repo.topicQuestionCount(subject.id, t.id);
              final st = topicStats[t.id];
              final acc = st == null || st.attempts == 0 ? null : st.accuracy;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(t.name.of(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr(
                        '$n प्रश्न${s.repo.note(subject.id, t.id) != null ? ' · नोट्स व माइंड मैप' : ''}',
                        '$n questions${s.repo.note(subject.id, t.id) != null ? ' · notes & mind map' : ''}')),
                    if (acc != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: acc,
                              minHeight: 6,
                              color: acc >= 0.7
                                  ? BrandColors.correct
                                  : (acc >= 0.4 ? BrandColors.saffron : BrandColors.wrong),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // The subject-level tiles show accuracy as a %, but this
                        // per-topic bar was color-only -- color alone (red/
                        // yellow/green) isn't accessible to colorblind users and
                        // gives no precise number either.
                        Text('${(acc * 100).round()}%',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                      ]),
                    ],
                  ]),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle, color: BrandColors.saffron, size: 34),
                    tooltip: context.tr('अभ्यास शुरू करें', 'Start practice'),
                    onPressed: n == 0
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            startQuiz(context, s.builder.practice(subject: subject.id, topic: t.id));
                          },
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    push(context, (_) => TopicScreen(subject: subject, topic: t));
                  },
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
          const AdSlot(),
        ],
      ),
    );
  }
}
