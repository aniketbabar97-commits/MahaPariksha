import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/ads.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../logic/percentile.dart';
import '../widgets/common.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';

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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 36)),
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(context.tr('साप्ताहिक कार्ड 🗓️', 'Weekly card 🗓️'), maxLines: 1, overflow: TextOverflow.ellipsis),
            onPressed: () {
              HapticFeedback.selectionClick();
              _shareWeeklyCard(context, p, lang);
            },
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
            CountUpText(p.xp,
                format: (v) => '$v\nXP',
                textAlign: TextAlign.center,
                duration: const Duration(milliseconds: 700),
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
        _BeastBadge(p: p, lang: lang),
        SectionTitle(context.tr('अभ्यास कैलेंडर 🗓️', 'Study calendar 🗓️')),
        _Heatmap(counts: p.dayCounts, goal: p.dailyGoal),
        if (exam != null) ...[
          SectionTitle(context.tr('परीक्षा वेटेज 📊', 'Exam weightage 📊')),
          _WeightageCard(exam: exam, subjects: subjects, lang: lang),
        ],
        SectionTitle(context.tr('विषयवार सटीकता 🎯', 'Accuracy by subject 🎯')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              for (final sub in subjects)
                Builder(builder: (context) {
                  final st = subjectStats[sub.id];
                  final acc = st == null || st[0] == 0 ? null : st[1] / st[0];
                  return InkWell(
                    // These rows showed per-subject accuracy but did nothing
                    // when tapped -- the natural next step from "here's how
                    // you're doing in X" is jumping straight into that subject.
                    onTap: () {
                      HapticFeedback.selectionClick();
                      push(context, (_) => SubjectScreen(subject: sub));
                    },
                    child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(subjectIcon(sub.icon), size: 16, color: Theme.of(context).hintColor),
                      const SizedBox(width: 6),
                      SizedBox(width: 96, child: Text(sub.name.of(lang), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: acc ?? 0),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 10,
                              backgroundColor: Colors.grey.withValues(alpha: 0.15),
                              color: acc == null
                                  ? Colors.transparent
                                  : (acc >= 0.7 ? BrandColors.correct : (acc >= 0.4 ? BrandColors.saffron : BrandColors.wrong)),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(acc == null ? '—' : '${(acc * 100).round()}%',
                            textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    ),
                  );
                }),
            ]),
          ),
        ),
        if (weak.isNotEmpty) ...[
          Row(children: [
            Expanded(child: SectionTitle(context.tr('सुधार की ज़रूरत वाले टॉपिक 💪', 'Topics to improve 💪'))),
            TextButton.icon(
              icon: const Icon(Icons.center_focus_strong, size: 16),
              label: Text(context.tr('सभी ड्रिल करें', 'Drill all')),
              onPressed: () {
                HapticFeedback.selectionClick();
                startQuiz(context, s.builder.weakSpots());
              },
            ),
          ]),
          for (final t in weak.take(5))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.trending_up, color: BrandColors.saffron),
                title: Text(s.repo.topic(t.subject, t.topic)?.name.of(lang) ?? t.topic),
                subtitle: Text(s.repo.subject(t.subject)?.name.of(lang) ?? ''),
                trailing: Text('${(t.accuracy * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                // A list literally titled "Topics to improve" had no way to
                // act on that -- tapping did nothing. The obvious next step
                // from "you're weak here" is practicing that exact topic now.
                onTap: () {
                  HapticFeedback.selectionClick();
                  startQuiz(context, s.builder.practice(subject: t.subject, topic: t.topic));
                },
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
                  trailing: m.total > 0
                      ? Text('~${context.tr('टॉप', 'Top')} ${100 - estimatedPercentile(m.score.clamp(0, m.total.toDouble()) / m.total)}%',
                          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5))
                      : null,
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
        if (p.freezeTokens < 2 && !p.removedAds) ...[
          const SizedBox(height: 12),
          _FreezeTokenCard(p: p),
        ],
        if (!p.removedAds) ...[
          const SizedBox(height: 16),
          const Center(child: AdBanner()),
        ],
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

/// Lets the user top up a streak-freeze token (capped at 2, see
/// [Progress.freezeTokens]) by watching a short rewarded ad -- an opt-in
/// exchange shown only while they're below the cap, so it never nags
/// someone who already has freezes banked. Freeze tokens otherwise only
/// come from a 7-day streak milestone, so this is the one way to get one
/// on demand right before a day you know you'll miss.
class _FreezeTokenCard extends StatelessWidget {
  final Progress p;
  const _FreezeTokenCard({required this.p});

  @override
  Widget build(BuildContext context) {
    RewardedAdManager.preload();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.ac_unit, color: BrandColors.saffron),
        title: Text(context.tr('स्ट्रीक फ्रीज़ कमाएं ❄️', 'Earn a streak freeze ❄️')),
        subtitle: Text(context.tr(
            'एक छोटा विज्ञापन देखें और एक दिन मिस होने पर भी स्ट्रीक बचाने वाला टोकन पाएं',
            'Watch a short ad to earn a token that saves your streak if you miss a day')),
        trailing: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
          icon: const Icon(Icons.play_circle_outline, size: 18),
          label: Text(context.tr('देखें', 'Watch')),
          onPressed: () {
            HapticFeedback.selectionClick();
            final shown = RewardedAdManager.showIfReady(onReward: () {
              p.update((pr) => pr.freezeTokens = (pr.freezeTokens + 1).clamp(0, 2));
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(context.tr('फ्रीज़ टोकन मिला! ❄️', 'Freeze token earned! ❄️'))));
            });
            if (!shown) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      context.tr('विज्ञापन अभी तैयार नहीं है, कृपया थोड़ी देर बाद कोशिश करें',
                          'Ad isn\'t ready yet -- please try again shortly'))));
            }
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _Stat({required this.value, required this.label, required this.icon});

  /// Parses a leading integer off [value] (e.g. "42" or "87%") so it can be
  /// counted up; the remaining suffix (like "%") is preserved as-is.
  (int, String)? _numeric() {
    final m = RegExp(r'^(\d+)(.*)$').firstMatch(value);
    if (m == null) return null;
    return (int.parse(m.group(1)!), m.group(2)!);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _numeric();
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            Icon(icon, color: BrandColors.saffron),
            const SizedBox(height: 4),
            parsed == null
                ? Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: parsed.$1.toDouble()),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text('${v.round()}${parsed.$2}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          ]),
        ),
      ),
    );
  }
}

/// A small tier indicator for Beast Mode (see beast_mode_screen.dart), shown next to the
/// existing _Stat tiles. Animates the same way those tiles and the accuracy bars above do:
/// `TweenAnimationBuilder<double>`, 700ms, Curves.easeOutCubic.
class _BeastBadge extends StatelessWidget {
  final Progress p;
  final String lang;
  const _BeastBadge({required this.p, required this.lang});

  @override
  Widget build(BuildContext context) {
    final tier = p.beastTier;
    final next = tier.nextScore;
    final into = next == null ? 1.0 : ((p.beastBestScore - tier.minScore) / (next - tier.minScore)).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: BrandColors.wrong.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.bolt, color: BrandColors.wrong),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(context.tr('बीस्ट मोड', 'Beast Mode'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 6),
                Text(tier.of(lang), style: const TextStyle(fontWeight: FontWeight.w900, color: BrandColors.saffron, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: into),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: Colors.grey.withValues(alpha: 0.15),
                    color: BrandColors.wrong,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: p.beastBestScore),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ),
        ]),
      ),
    );
  }
}

/// Shows each subject's share of the selected exam's real paper -- the same
/// per-subject weighting [QuizBuilder.mock] uses to build a mock test that
/// mirrors the actual exam instead of an even split. That weighting drove
/// question allocation already but was never shown to the student; placed
/// directly above "Accuracy by subject" below so the same row layout lets
/// a student line up "how much of my exam is this" against "how good am I
/// at this" at a glance.
class _WeightageCard extends StatelessWidget {
  final Exam exam;
  final List<Subject> subjects;
  final String lang;
  const _WeightageCard({required this.exam, required this.subjects, required this.lang});

  @override
  Widget build(BuildContext context) {
    final totalWeight = subjects.fold(0, (a, s) => a + (exam.weights[s.id] ?? 1));
    final sorted = [...subjects]..sort((a, b) => (exam.weights[b.id] ?? 1).compareTo(exam.weights[a.id] ?? 1));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            context.tr(
                'असली पेपर में हर विषय से कितने प्रश्न आते हैं — ज़्यादा हिस्सेदारी वाले विषय को पहले मज़बूत करें',
                "Each subject's share of questions in the real paper -- strengthen the heavier ones first"),
            style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          if (totalWeight > 0)
            for (final sub in sorted)
              Builder(builder: (context) {
                final share = (exam.weights[sub.id] ?? 1) / totalWeight;
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    push(context, (_) => SubjectScreen(subject: sub));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(subjectIcon(sub.icon), size: 16, color: Theme.of(context).hintColor),
                      const SizedBox(width: 6),
                      SizedBox(width: 96, child: Text(sub.name.of(lang), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: share),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 10,
                              backgroundColor: Colors.grey.withValues(alpha: 0.15),
                              color: BrandColors.sky,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text('${(share * 100).round()}%',
                            textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                );
              }),
        ]),
      ),
    );
  }
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
                    if (day > t) {
                      // Future day, nothing to announce -- an empty node would
                      // otherwise still get swipe focus with nothing to say.
                      return const SizedBox(width: 16, height: 16, child: SizedBox.shrink());
                    }
                    final date = DateTime.fromMillisecondsSinceEpoch(day * 86400000, isUtc: true);
                    // A ~84-cell study calendar had no Semantics at all -- a
                    // screen-reader user got nothing meaningful from the whole
                    // heatmap. One label per cell (date + questions that day)
                    // makes the same info the color encodes available to them.
                    return Semantics(
                      label: context.tr(
                          '${date.day}/${date.month}: $n प्रश्न',
                          '${date.day}/${date.month}: $n questions'),
                      child: Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: n == 0 ? Colors.grey.withValues(alpha: 0.15) : BrandColors.saffron.withValues(alpha: v),
                          borderRadius: BorderRadius.circular(4),
                          border: day == t ? Border.all(color: BrandColors.sky, width: 1.5) : null,
                        ),
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
