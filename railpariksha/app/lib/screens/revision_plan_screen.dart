import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../logic/revision_planner.dart';
import '../widgets/common.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import '../core/ads.dart';

/// Turns the exam countdown (set in the Me tab) into a concrete three-phase
/// plan -- Foundation, Weak-Topic Focus, Final Revision -- so "I have an app"
/// becomes "I have a plan". Phase is derived purely from [Progress.daysToExam]
/// (see RevisionPlanner), never stored, so it can't drift if the exam date
/// changes or the days simply tick down.
class RevisionPlanScreen extends StatelessWidget {
  const RevisionPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final p = s.progress;
    final planner = RevisionPlanner(s.builder);
    final phase = planner.phase;
    final days = p.daysToExam;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('रिवीज़न प्लान 🗓️', 'Revision plan 🗓️'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (days == null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Icon(Icons.event, color: BrandColors.skyOn(context), size: 40),
                  const SizedBox(height: 10),
                  Text(context.tr('कोई परीक्षा तारीख सेट नहीं है', 'No exam date set'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                      context.tr('अपनी परीक्षा की तारीख डालें ताकि आपके लिए एक निजी रिवीज़न प्लान बन सके',
                          'Set your exam date to get a plan tailored to how many days you have left'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).hintColor)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.edit_calendar),
                    label: Text(context.tr('तारीख चुनें', 'Pick a date')),
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        helpText: context.tr('परीक्षा की तारीख चुनें', 'Select exam date'),
                        cancelText: context.tr('रद्द करें', 'Cancel'),
                        confirmText: context.tr('ठीक है', 'OK'),
                        context: context,
                        initialDate: now.add(const Duration(days: 60)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 730)),
                      );
                      if (d != null) p.update((p) => p.examDate = d);
                    },
                  ),
                ]),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: BrandColors.heroGradient, borderRadius: BorderRadius.circular(24)),
              child: Column(children: [
                CountUpText(days,
                    duration: const Duration(milliseconds: 800),
                    style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
                Text(context.tr('दिन बाकी', 'days left'), style: const TextStyle(color: Colors.white70, fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 16),
            _PhaseCard(
              current: phase == RevisionPhase.foundation,
              icon: Icons.school,
              titleHi: 'नींव बनाएं',
              titleEn: 'Build the foundation',
              rangeHi: '21+ दिन बाकी',
              rangeEn: '21+ days left',
              bodyHi: 'हर विषय और टॉपिक को कम से कम एक बार पढ़ें और अभ्यास करें। अभी नए टॉपिक सीखने का सबसे अच्छा समय है।',
              bodyEn: 'Touch every subject and topic at least once. This is the best window left to learn anything new.',
            ),
            const SizedBox(height: 10),
            _PhaseCard(
              current: phase == RevisionPhase.weakFocus,
              icon: Icons.center_focus_strong,
              titleHi: 'कमज़ोर टॉपिक पर फोकस',
              titleEn: 'Focus on weak topics',
              rangeHi: '6–20 दिन बाकी',
              rangeEn: '6-20 days left',
              bodyHi: 'अब नए टॉपिक कम सीखें, अपने सबसे कमज़ोर टॉपिक पर ड्रिल करें और गलतियों की कॉपी दोहराएं।',
              bodyEn: 'Taper off new topics. Drill your weakest topics hard and clear your mistake book.',
            ),
            const SizedBox(height: 10),
            _PhaseCard(
              current: phase == RevisionPhase.finalRevision,
              icon: Icons.flag_circle,
              titleHi: 'सिर्फ रिवीज़न',
              titleEn: 'Pure revision',
              rangeHi: 'आखिरी 6 दिन',
              rangeEn: 'Last 6 days',
              bodyHi: 'कोई नया टॉपिक नहीं! सिर्फ फ्लैशकार्ड दोहराएं, गलतियां सुधारें और 1-2 फुल-लेंथ मॉक दें।',
              bodyEn: 'No new topics now. Just flashcard revision, mistake cleanup, and 1-2 full-length mocks.',
            ),
          ],
          const SizedBox(height: 20),
          if (days != null) _TodayActions(phase: phase),
        ],
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  final bool current;
  final IconData icon;
  final String titleHi, titleEn, rangeHi, rangeEn, bodyHi, bodyEn;
  const _PhaseCard({
    required this.current,
    required this.icon,
    required this.titleHi,
    required this.titleEn,
    required this.rangeHi,
    required this.rangeEn,
    required this.bodyHi,
    required this.bodyEn,
  });

  @override
  Widget build(BuildContext context) {
    final color = current ? BrandColors.saffron : Theme.of(context).hintColor;
    return Card(
      color: current ? BrandColors.saffron.withValues(alpha: 0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: current ? const BorderSide(color: BrandColors.saffron, width: 1.5) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(context.tr(titleHi, titleEn),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: current ? null : color)),
            ),
            if (current)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: BrandColors.saffron, borderRadius: BorderRadius.circular(20)),
                child: Text(context.tr('अभी', 'NOW'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
              ),
          ]),
          const SizedBox(height: 4),
          Text(context.tr(rangeHi, rangeEn), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          const SizedBox(height: 8),
          Text(context.tr(bodyHi, bodyEn), style: const TextStyle(height: 1.4, fontSize: 13.5)),
        ]),
      ),
    );
  }
}

/// Concrete, tappable actions for the current phase, built from exactly the
/// same QuizBuilder methods the rest of the app already uses -- this screen
/// doesn't invent new study content, it just points at the right existing
/// tool for where the user is in their countdown.
class _TodayActions extends StatelessWidget {
  final RevisionPhase? phase;
  const _TodayActions({required this.phase});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final gaps = s.builder.pacingGaps();
    final dueCount = s.builder.dueCards(limit: 999).length;
    final mistakeCount = s.progress.mistakes.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(context.tr('अभी करें', 'Do this now')),
      switch (phase) {
        RevisionPhase.foundation => () {
            final gapName = gaps.isEmpty ? null : s.repo.subject(gaps.first.subject)?.name.of(context.lang);
            return ActionCard(
              icon: Icons.menu_book,
              color: BrandColors.sky,
              title: gapName != null
                  ? context.tr('$gapName का अभ्यास करें', 'Practice $gapName')
                  : context.tr('आज का Daily 10', "Today's Daily 10"),
              subtitle: context.tr('हर विषय को बराबर समय दें', 'Give every subject even coverage'),
              onTap: () => startQuiz(context, gapName != null ? s.builder.practice(subject: gaps.first.subject) : s.builder.daily()),
            );
          }(),
        RevisionPhase.weakFocus => ActionCard(
            icon: Icons.center_focus_strong,
            color: BrandColors.saffron,
            title: context.tr('कमज़ोर टॉपिक ड्रिल', 'Weak spots drill'),
            subtitle: context.tr('सबसे कमज़ोर टॉपिक पर सीधा अभ्यास', 'Direct practice on your weakest topics'),
            onTap: () => startQuiz(context, s.builder.weakSpots()),
          ),
        RevisionPhase.finalRevision => ActionCard(
            icon: Icons.style,
            color: BrandColors.skyLight,
            title: context.tr('फ्लैशकार्ड रिवीज़न', 'Flashcard revision'),
            subtitle: context.tr('$dueCount कार्ड आज रिवीज़न के लिए', '$dueCount cards due today'),
            onTap: () => push(context, (_) => const FlashcardScreen()),
          ),
        null => const SizedBox.shrink(),
      },
      if (phase == RevisionPhase.weakFocus || phase == RevisionPhase.finalRevision) ...[
        const SizedBox(height: 10),
        ActionCard(
          icon: Icons.replay_circle_filled,
          color: BrandColors.wrong,
          title: context.tr('गलतियों की कॉपी', 'Mistake book'),
          subtitle: mistakeCount == 0
              ? context.tr('कोई गलती बाकी नहीं! 👏', 'No pending mistakes! 👏')
              : context.tr('$mistakeCount प्रश्न दोबारा हल करें', 'Retry $mistakeCount questions'),
          onTap: mistakeCount == 0 ? null : () => startQuiz(context, s.builder.mistakes()),
        ),
      ],
      if (phase == RevisionPhase.finalRevision) ...[
        const SizedBox(height: 10),
        ActionCard(
          icon: Icons.assignment,
          color: BrandColors.correct,
          title: context.tr('फुल-लेंथ मॉक', 'Full-length mock'),
          subtitle: context.tr('असली परीक्षा जैसा एक पूरा पेपर', 'One complete paper, real exam conditions'),
          onTap: () => startQuiz(context, s.builder.mock(full: true)),
        ),
      ],
            const AdSlot(),
      ]);
  }
}
