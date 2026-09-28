import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/progress.dart';
import '../widgets/common.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final p = s.progress;
    final lang = context.lang;
    final exam = s.builder.exam;
    final subjectStats = s.builder.subjectStats();
    final subjects = exam == null ? s.repo.subjects : s.repo.subjectsFor(exam);
    final weak = s.builder.topicStats().where((t) => t.attempts >= 3).toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final level = p.level;
    final examMocks = p.mocks.where((m) => m.examId == p.examId).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(children: [
          Expanded(
            child: Text(context.tr('प्रगति 📈', 'Progress 📈'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(context.tr('साप्ताहिक कार्ड 🗓️', 'Weekly card 🗓️')),
            onPressed: () => _shareWeeklyCard(context, p, lang),
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: BrandColors.heroGradient, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            const Icon(Icons.military_tech, color: BrandColors.sunrise, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(level.of(lang), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                Text(
                    level.nextXp == null
                        ? context.tr('सर्वोच्च स्तर! 👑', 'Top level! 👑')
                        : context.tr('अगले स्तर के लिए ${level.nextXp! - p.xp} XP', '${level.nextXp! - p.xp} XP to next level'),
                    style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            Text('${p.xp}\nXP',
                textAlign: TextAlign.center,
                style: const TextStyle(color: BrandColors.sunrise, fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _Stat(value: '${p.totalAnswered}', label: context.tr('प्रश्न हल किए', 'Answered'), icon: Icons.edit),
          const SizedBox(width: 10),
          _Stat(value: '${(p.accuracy * 100).round()}%', label: context.tr('सटीकता', 'Accuracy'), icon: Icons.track_changes),
          const SizedBox(width: 10),
          _Stat(value: '${p.bestStreak}', label: context.tr('सर्वश्रेष्ठ स्ट्रीक', 'Best streak'), icon: Icons.local_fire_department),
        ]),
        SectionTitle(context.tr('अभ्यास कैलेंडर 🗓️', 'Study calendar 🗓️')),
        _Heatmap(counts: p.dayCounts, goal: p.dailyGoal),
        SectionTitle(context.tr('विषयवार सटीकता 🎯', 'Accuracy by subject 🎯')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              for (final sub in subjects)
                Builder(builder: (context) {
                  final st = subjectStats[sub.id];
                  final acc = st == null || st[0] == 0 ? null : st[1] / st[0];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      SizedBox(width: 110, child: Text(sub.name.of(lang), overflow: TextOverflow.ellipsis)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: acc ?? 0,
                            minHeight: 10,
                            backgroundColor: Colors.grey.withValues(alpha: 0.15),
                            color: acc == null
                                ? Colors.transparent
                                : (acc >= 0.7 ? BrandColors.correct : (acc >= 0.4 ? BrandColors.saffron : BrandColors.wrong)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(acc == null ? '—' : '${(acc * 100).round()}%',
                            textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  );
                }),
            ]),
          ),
        ),
        if (weak.isNotEmpty) ...[
          SectionTitle(context.tr('सुधार की ज़रूरत वाले टॉपिक 💪', 'Topics to improve 💪')),
          for (final t in weak.take(5))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.trending_up, color: BrandColors.saffron),
                title: Text(s.repo.topic(t.subject, t.topic)?.name.of(lang) ?? t.topic),
                subtitle: Text(s.repo.subject(t.subject)?.name.of(lang) ?? ''),
                trailing: Text('${(t.accuracy * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ],
        if (examMocks.isNotEmpty) ...[
          SectionTitle(context.tr('मॉक टेस्ट इतिहास 🏆', 'Mock test history 🏆')),
          Card(
            child: Column(children: [
              for (final m in examMocks.reversed.take(8))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.assignment_turned_in, color: BrandColors.sky),
                  title: Text('${m.score.toStringAsFixed(m.score == m.score.roundToDouble() ? 0 : 2)} / ${m.total}'),
                  subtitle: Text(_dateOf(m.day)),
                ),
            ]),
          ),
        ],
        SectionTitle(context.tr('बैज 🎖️', 'Badges 🎖️')),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final b in _badges(p))
            Chip(
              avatar: Icon(b.$3 ? Icons.verified : Icons.lock_outline, color: b.$3 ? BrandColors.saffron : Colors.grey, size: 18),
              label: Text(lang == 'en' ? b.$2 : b.$1),
            ),
        ]),
      ],
    );
  }

  static String _dateOf(int day) {
    final d = DateTime.fromMillisecondsSinceEpoch(day * 86400000, isUtc: true);
    return '${d.day}/${d.month}/${d.year}';
  }

  static List<(String, String, bool)> _badges(Progress p) => [
        ('पहला कदम', 'First step', p.totalAnswered >= 1),
        ('100 प्रश्न', '100 questions', p.totalAnswered >= 100),
        ('1000 प्रश्न', '1,000 questions', p.totalAnswered >= 1000),
        ('7 दिन स्ट्रीक', '7-day streak', p.bestStreak >= 7),
        ('30 दिन स्ट्रीक', '30-day streak', p.bestStreak >= 30),
        ('मॉक योद्धा', 'Mock warrior', p.mocks.length >= 5),
        ('स्पीडस्टार', 'Speedster', p.bestSpeed >= 15),
        ('गलतियों पर जीत', 'Mistake crusher', p.totalAnswered >= 50 && p.mistakes.isEmpty),
      ];
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _Stat({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(children: [
              Icon(icon, color: BrandColors.saffron),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ]),
          ),
        ),
      );
}

class _Heatmap extends StatelessWidget {
  final Map<int, int> counts;
  final int goal;
  const _Heatmap({required this.counts, required this.goal});

  @override
  Widget build(BuildContext context) {
    final t = today();
    const weeks = 12;
    final start = t - (weeks * 7 - 1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var w = 0; w < weeks; w++)
              Column(children: [
                for (var d = 0; d < 7; d++)
                  Builder(builder: (context) {
                    final day = start + w * 7 + d;
                    final n = counts[day] ?? 0;
                    final v = n == 0 ? 0.0 : (0.25 + 0.75 * (n / goal).clamp(0.0, 1.0));
                    return Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: day > t
                            ? Colors.transparent
                            : (n == 0 ? Colors.grey.withValues(alpha: 0.15) : BrandColors.saffron.withValues(alpha: v)),
                        borderRadius: BorderRadius.circular(4),
                        border: day == t ? Border.all(color: BrandColors.sky, width: 1.5) : null,
                      ),
                    );
                  }),
              ]),
          ],
        ),
      ),
    );
  }
}
void _shareWeeklyCard(BuildContext context, Progress p, String lang) {
  final t = today();
  var weekCount = 0;
  for (var d = t - 6; d <= t; d++) {
    weekCount += p.dayCounts[d] ?? 0;
  }
  final acc = (p.accuracy * 100).round();
  final streak = p.liveStreak;
  final level = p.level;
  final hi = 'मेरी RailPariksha साप्ताहिक रिपोर्ट 🗓️\n'
      '✅ इस हफ्ते $weekCount प्रश्न हल किए\n'
      '🎯 कुल सटीकता: $acc%\n'
      '🔥 मौजूदा स्ट्रीक: $streak दिन\n'
      '🏅 स्तर: ${level.hi}\n\n'
      'आप भी अभ्यास शुरू करें — मुफ़्त प्रैक्टिस ऐप 🚀';
  final en = 'My RailPariksha weekly report 🗓️\n'
      '✅ $weekCount questions this week\n'
      '🎯 Overall accuracy: $acc%\n'
      '🔥 Current streak: $streak days\n'
      '🏅 Level: ${level.en}\n\n'
      'Join me on RailPariksha — free practice app 🚀';
  SharePlus.instance.share(ShareParams(text: lang == 'en' ? en : hi));
}
