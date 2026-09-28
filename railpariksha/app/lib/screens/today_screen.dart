import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../logic/quiz_builder.dart';
import '../widgets/common.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'reel_screen.dart';
import 'search_screen.dart';

class TodayScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const TodayScreen({super.key, required this.onNavigate});

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 12) return context.tr('सुप्रभात! 🌅', 'Good morning! 🌅');
    if (h < 17) return context.tr('नमस्ते! ☀️', 'Good afternoon! ☀️');
    return context.tr('शुभ संध्या! 🌙', 'Good evening! 🌙');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final p = s.progress;
    final exam = s.builder.exam;
    final lang = context.lang;
    final dueCards = s.builder.dueCards(limit: 999).length;
    final motivation = s.builder.todaysMotivation();
    final days = p.daysToExam;
    final level = p.level;
    final gaps = days == null ? <PacingGap>[] : s.builder.pacingGaps();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Hero: greeting, level, streak, goal ring
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: BrandColors.heroGradient, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting(context),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(exam?.name.of(lang) ?? '', style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              StreakWings(streak: p.liveStreak),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              GoalRing(
                progress: p.goalProgress,
                size: 110,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${p.todayCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  Text('/ ${p.dailyGoal}', style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    p.todayCount >= p.dailyGoal
                        ? context.tr('आज का लक्ष्य पूरा! 🎉', 'Goal complete! 🎉')
                        : context.tr('आज का लक्ष्य', "Today's goal"),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  Text('${level.of(lang)} · ${p.xp} XP', style: const TextStyle(color: BrandColors.sunrise, fontWeight: FontWeight.w700)),
                  if (level.nextXp != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (p.xp - level.minXp) / (level.nextXp! - level.minXp),
                        minHeight: 7,
                        backgroundColor: Colors.white24,
                        color: BrandColors.sunrise,
                      ),
                    ),
                  ],
                  if (days != null) ...[
                    const SizedBox(height: 10),
                    Text(context.tr('परीक्षा में $days दिन बाकी ⏳', '$days days to exam ⏳'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ]),
          ]),
        ),
        if (p.comeback && !p.activeToday) ...[
          const SizedBox(height: 12),
          Card(
            color: BrandColors.saffron.withValues(alpha: 0.15),
            child: ListTile(
              leading: const Icon(Icons.bolt, color: BrandColors.saffron),
              title: Text(context.tr('वापसी पर स्वागत है! कमबैक बोनस 💪', 'Welcome back! Comeback bonus 💪'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(context.tr('रुकना हार नहीं है, दोबारा शुरुआत करना ही असली जज़्बा है।',
                  'Pausing is not losing. Restarting is true grit.')),
            ),
          ),
        ],
        if (gaps.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.insights, color: BrandColors.sky, size: 20),
                  const SizedBox(width: 8),
                  Text(context.tr('अध्ययन योजना', 'Study plan'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ]),
                const SizedBox(height: 10),
                for (final g in gaps)
                  Builder(builder: (context) {
                    final sub = s.repo.subject(g.subject);
                    final name = sub?.name.of(lang) ?? g.subject;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => startQuiz(context, s.builder.practice(subject: g.subject)),
                        child: Row(children: [
                          Icon(subjectIcon(sub?.icon ?? ''), color: BrandColors.saffron, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('आप $name में पीछे हैं — आज ~${g.recommendedDaily} प्रश्न करें',
                                  "You're behind on $name — try ~${g.recommendedDaily} Qs today"),
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        ]),
                      ),
                    );
                  }),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Reel Mode: the addictive endless swipe feed — most prominent CTA.
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReelScreen())),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: BrandColors.heroGradient),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(context.tr('रील मोड', 'Reel Mode'),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: BrandColors.saffron, borderRadius: BorderRadius.circular(20)),
                        child: Text(context.tr('नया', 'NEW'), style: const TextStyle(color: BrandColors.sky, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(context.tr('स्वाइप करें, सीखते रहें — कभी न रुकने वाला अभ्यास 🔥', 'Swipe, learn, repeat — endless bite-sized practice 🔥'),
                        style: const TextStyle(color: Colors.white70)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Primary CTA
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => startQuiz(context, s.builder.daily()),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: BrandColors.fireGradient),
              child: Row(children: [
                const Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('आज का Daily 10', "Today's Daily 10"),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    Text(context.tr('आपके कमज़ोर विषयों पर खास प्रश्न', 'Picked for your weak topics'),
                        style: const TextStyle(color: Colors.white)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.search,
          color: BrandColors.sky,
          title: context.tr('प्रश्न व नोट्स खोजें', 'Search questions & notes'),
          subtitle: context.tr('किसी भी टॉपिक या कीवर्ड पर सीधे जाएं', 'Jump straight to any topic or keyword'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.style,
          color: BrandColors.skyLight,
          title: context.tr('फ्लैशकार्ड रिवीज़न', 'Flashcard revision'),
          subtitle: context.tr('$dueCards कार्ड आज रिवीज़न के लिए', '$dueCards cards due today'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashcardScreen())),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.replay_circle_filled,
          color: BrandColors.wrong,
          title: context.tr('गलतियों की कॉपी', 'Mistake book'),
          subtitle: p.mistakes.isEmpty
              ? context.tr('कोई गलती बाकी नहीं! 👏', 'No pending mistakes! 👏')
              : context.tr('${p.mistakes.length} प्रश्न दोबारा हल करें', 'Retry ${p.mistakes.length} questions'),
          onTap: p.mistakes.isEmpty ? null : () => startQuiz(context, s.builder.mistakes()),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.timer,
          color: BrandColors.correct,
          title: context.tr('60 सेकंड स्पीड राउंड', '60-second Speed Round'),
          subtitle: context.tr('सर्वश्रेष्ठ: ${p.bestSpeed} · सफ़र के लिए बढ़िया', 'Best: ${p.bestSpeed} · perfect for travel'),
          onTap: () => startQuiz(context, s.builder.speed()),
        ),
        if (motivation != null) ...[
          SectionTitle(context.tr('आज की प्रेरणा 🔥', "Today's motivation 🔥")),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(
                      switch (motivation.type) {
                        'story' => Icons.auto_stories,
                        'tip' => Icons.tips_and_updates,
                        _ => Icons.format_quote,
                      },
                      color: BrandColors.saffron),
                  const SizedBox(width: 8),
                  Text(
                      switch (motivation.type) {
                        'story' => context.tr('प्रेरक कहानी', 'Inspiring story'),
                        'tip' => context.tr('अध्ययन टिप', 'Study tip'),
                        _ => context.tr('सुविचार', 'Quote'),
                      },
                      style: const TextStyle(fontWeight: FontWeight.w700, color: BrandColors.saffron)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: context.tr('शेयर करें', 'Share'),
                    onPressed: () => SharePlus.instance.share(ShareParams(
                        text: '${motivation.text.of(lang)}${motivation.by != null ? '\n— ${motivation.by}' : ''}'
                            '\n\n${context.tr('RailPariksha ऐप पर रोज़ाना प्रेरणा और अभ्यास', 'Daily practice & motivation on the RailPariksha app')} 🚀')),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(motivation.text.of(lang), style: const TextStyle(fontSize: 17, height: 1.5)),
                if (motivation.by != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('— ${motivation.by}', style: const TextStyle(fontStyle: FontStyle.italic)),
                  ),
                ],
              ]),
            ),
          ),
        ],
        SectionTitle(context.tr('आगे क्या?', "What's next?")),
        ActionCard(
          icon: Icons.assignment,
          color: BrandColors.sky,
          title: context.tr('पूर्ण मॉक टेस्ट', 'Full mock test'),
          subtitle: context.tr('समय सीमा के साथ · असली परीक्षा जैसा अनुभव', 'Timed · real exam feel'),
          onTap: () => startQuiz(context, s.builder.mock()),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.menu_book,
          color: BrandColors.skyLight,
          title: context.tr('विषयवार अभ्यास', 'Practice by subject'),
          subtitle: context.tr('विषय → टॉपिक → अभ्यास', 'Subject → topic → practice'),
          onTap: () => onNavigate(1),
        ),
      ],
    );
  }
}
