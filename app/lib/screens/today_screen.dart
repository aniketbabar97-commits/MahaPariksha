import '../core/transitions.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';

class TodayScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const TodayScreen({super.key, required this.onNavigate});

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 12) return context.tr('सुप्रभात! 🌅', 'Good morning! 🌅');
    if (h < 17) return context.tr('नमस्कार! ☀️', 'Good afternoon! ☀️');
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
                        ? context.tr('आजचं लक्ष्य पूर्ण! 🎉', 'Goal complete! 🎉')
                        : context.tr('आजचं लक्ष्य', "Today's goal"),
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
                    Text(context.tr('परीक्षेला $days दिवस बाकी ⏳', '$days days to exam ⏳'),
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
              title: Text(context.tr('पुन्हा स्वागत! Comeback बोनस 💪', 'Welcome back! Comeback bonus 💪'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(context.tr('थांबणं हार नाही, पुन्हा सुरुवात करणं हीच जिद्द.',
                  'Pausing is not losing. Restarting is true grit.')),
            ),
          ),
        ],
        const SizedBox(height: 16),
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
                    Text(context.tr('आजचे Daily 10', "Today's Daily 10"),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    Text(context.tr('तुमच्या कमकुवत विषयांवर खास प्रश्न', 'Picked for your weak topics'),
                        style: const TextStyle(color: Colors.white)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.style,
          color: BrandColors.skyLight,
          title: context.tr('फ्लॅशकार्ड उजळणी', 'Flashcard revision'),
          subtitle: context.tr('$dueCards कार्ड आज उजळणीसाठी', '$dueCards cards due today'),
          onTap: () => push(context, (_) => const FlashcardScreen()),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.replay_circle_filled,
          color: BrandColors.wrong,
          title: context.tr('चुकांची वही', 'Mistake book'),
          subtitle: p.mistakes.isEmpty
              ? context.tr('एकही चूक बाकी नाही! 👏', 'No pending mistakes! 👏')
              : context.tr('${p.mistakes.length} प्रश्न पुन्हा सोडवा', 'Retry ${p.mistakes.length} questions'),
          onTap: p.mistakes.isEmpty ? null : () => startQuiz(context, s.builder.mistakes()),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.timer,
          color: BrandColors.correct,
          title: context.tr('60 सेकंद स्पीड राउंड', '60-second Speed Round'),
          subtitle: context.tr('सर्वोत्तम: ${p.bestSpeed} · प्रवासासाठी उत्तम', 'Best: ${p.bestSpeed} · perfect for travel'),
          onTap: () => startQuiz(context, s.builder.speed()),
        ),
        if (motivation != null) ...[
          SectionTitle(context.tr('आजची प्रेरणा 🔥', "Today's motivation 🔥")),
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
                        'story' => context.tr('प्रेरणादायी कथा', 'Inspiring story'),
                        'tip' => context.tr('अभ्यास टिप', 'Study tip'),
                        _ => context.tr('सुविचार', 'Quote'),
                      },
                      style: const TextStyle(fontWeight: FontWeight.w700, color: BrandColors.saffron)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: context.tr('शेअर करा', 'Share'),
                    onPressed: () => SharePlus.instance.share(ShareParams(
                        text: '${motivation.text.of(lang)}${motivation.by != null ? '\n— ${motivation.by}' : ''}'
                            '\n\n${context.tr('भरारी ॲपवर रोज प्रेरणा आणि सराव', 'Daily practice & motivation on the Bharari app')} 🚀')),
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
        SectionTitle(context.tr('पुढे काय?', "What's next?")),
        ActionCard(
          icon: Icons.assignment,
          color: BrandColors.sky,
          title: context.tr('पूर्ण सराव परीक्षा (Mock)', 'Full mock test'),
          subtitle: context.tr('वेळेसह · परीक्षेसारखा अनुभव', 'Timed · real exam feel'),
          onTap: () => startQuiz(context, s.builder.mock()),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.menu_book,
          color: BrandColors.skyLight,
          title: context.tr('विषयानुसार सराव', 'Practice by subject'),
          subtitle: context.tr('विषय → घटक → सराव', 'Subject → topic → practice'),
          onTap: () => onNavigate(1),
        ),
      ],
    );
  }
}
