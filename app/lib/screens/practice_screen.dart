import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/exam_picker.dart';
import 'quiz_screen.dart';
import 'topic_screen.dart';

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
    if (exam == null) return const SizedBox();
    final subjects = s.repo.subjectsFor(exam);
    final stats = s.builder.subjectStats();
    final pool = s.repo.questionsFor(exam);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(children: [
          Expanded(
            child: Text(context.tr('सराव', 'Practice'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          ),
          ActionChip(
            avatar: const Icon(Icons.swap_horiz, size: 18),
            label: Text(exam.name.of(lang)),
            onPressed: () => showExamSwitcher(context),
          ),
        ]),
        const SizedBox(height: 4),
        Text(context.tr('${pool.length} प्रश्न · ${subjects.length} विषय', '${pool.length} questions · ${subjects.length} subjects'),
            style: TextStyle(color: Theme.of(context).hintColor)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: _QuickTile(
              icon: Icons.assignment,
              color: BrandColors.sky,
              label: context.tr('मॉक टेस्ट', 'Mock test'),
              onTap: () => startQuiz(context, s.builder.mock()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickTile(
              icon: Icons.timer,
              color: BrandColors.correct,
              label: context.tr('स्पीड राउंड', 'Speed round'),
              onTap: () => startQuiz(context, s.builder.speed()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickTile(
              icon: Icons.bookmark,
              color: BrandColors.saffron,
              label: context.tr('जतन केलेले', 'Saved'),
              onTap: () => startQuiz(context, s.builder.bookmarked()),
            ),
          ),
        ]),
        SectionTitle(context.tr('विषयानुसार सराव', 'Practice by subject')),
        for (final sub in subjects) ...[
          _SubjectTile(
            subject: sub,
            count: pool.where((q) => q.subject == sub.id).length,
            stat: stats[sub.id],
          ),
          const SizedBox(height: 10),
        ],
      ],
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
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
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
          ? context.tr('$count प्रश्न · सुरुवात करा', '$count questions · start now')
          : context.tr('$count प्रश्न · अचूकता ${(acc * 100).round()}%', '$count questions · ${(acc * 100).round()}% accuracy'),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectScreen(subject: subject))),
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
    final qs = s.repo.questions.where((q) => q.subject == subject.id).toList();
    final topicStats = {for (final t in s.builder.topicStats().where((t) => t.subject == subject.id)) t.topic: t};
    return Scaffold(
      appBar: AppBar(title: Text(subject.name.of(lang))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: BrandColors.saffron),
            icon: const Icon(Icons.shuffle),
            label: Text(context.tr('सर्व घटकांतून मिश्र सराव', 'Mixed practice from all topics')),
            onPressed: () => startQuiz(context, s.builder.practice(subject: subject.id)),
          ),
          SectionTitle(context.tr('घटक', 'Topics')),
          for (final t in subject.topics) ...[
            Builder(builder: (context) {
              final n = qs.where((q) => q.topic == t.id).length;
              final st = topicStats[t.id];
              final acc = st == null || st.attempts == 0 ? null : st.accuracy;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(t.name.of(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr(
                        '$n प्रश्न${s.repo.note(subject.id, t.id) != null ? ' · नोट्स व माइंड मॅप' : ''}',
                        '$n questions${s.repo.note(subject.id, t.id) != null ? ' · notes & mind map' : ''}')),
                    if (acc != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: acc,
                          minHeight: 6,
                          color: acc >= 0.7 ? BrandColors.correct : (acc >= 0.4 ? BrandColors.saffron : BrandColors.wrong),
                        ),
                      ),
                    ],
                  ]),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle, color: BrandColors.saffron, size: 34),
                    onPressed: n == 0 ? null : () => startQuiz(context, s.builder.practice(subject: subject.id, topic: t.id)),
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicScreen(subject: subject, topic: t))),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
