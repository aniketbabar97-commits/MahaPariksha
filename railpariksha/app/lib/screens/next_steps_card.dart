import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../logic/next_steps.dart';
import 'cheat_sheet_screen.dart';
import 'quiz_screen.dart';
import 'topic_screen.dart';

/// End-of-quiz "Your next step": the topics this quiz showed are weak, each with
/// one-tap fixes (focused practice, a quick revision, real PYQs on the topic),
/// plus a word of praise for the topic the student nailed.
class NextStepsCard extends StatelessWidget {
  final NextSteps steps;
  const NextStepsCard({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('आपका अगला कदम 🎯', 'Your next step 🎯'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          if (steps.weak.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              context.tr('इन टॉपिक पर ध्यान दें — 10 मिनट का अभ्यास बड़ा फर्क लाएगा।',
                  'Work on these next — 10 minutes of practice makes a real difference.'),
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
            ),
            for (final v in steps.weak) _WeakTopic(v: v),
          ],
          if (steps.strong != null) _StrongTopic(v: steps.strong!),
        ]),
      ),
    );
  }
}

class _WeakTopic extends StatelessWidget {
  final TopicVerdict v;
  const _WeakTopic({required this.v});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final lang = context.lang;
    final subject = s.repo.subject(v.subject);
    final topic = s.repo.topic(v.subject, v.topic);
    if (subject == null || topic == null) return const SizedBox.shrink();
    final practiceCount = s.repo.topicQuestionCount(v.subject, v.topic);
    final hasNote = s.repo.note(v.subject, v.topic) != null;
    final hasCheat = s.repo.hasCheatSheets(v.subject);
    final pyqCount = s.builder.pyqCountForTopic(v.subject, v.topic);
    final pct = (v.accuracy * 100).round();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.trending_down, size: 18, color: BrandColors.wrong),
          const SizedBox(width: 6),
          Expanded(
            child: Text(topic.name.of(lang),
                style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
          ),
          Text(
            context.tr('इस बार ${v.sessionCorrect}/${v.sessionAttempts} · कुल $pct%',
                'This quiz ${v.sessionCorrect}/${v.sessionAttempts} · overall $pct%'),
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (practiceCount > 0)
            ActionChip(
              avatar: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(context.tr('10 प्रश्न अभ्यास', 'Practise 10')),
              onPressed: () {
                HapticFeedback.selectionClick();
                startQuiz(context, s.builder.practice(subject: v.subject, topic: v.topic));
              },
            ),
          if (hasNote || hasCheat)
            ActionChip(
              avatar: const Icon(Icons.menu_book, size: 18),
              label: Text(context.tr('2 मिनट रिवीज़न', 'Revise in 2 min')),
              onPressed: () {
                HapticFeedback.selectionClick();
                push(context,
                    (_) => hasNote ? TopicScreen(subject: subject, topic: topic) : CheatSheetScreen(subject: subject));
              },
            ),
          if (pyqCount > 0)
            ActionChip(
              avatar: const Icon(Icons.history_edu, size: 18),
              label: Text(context.tr('इस टॉपिक के PYQ', 'PYQs on this topic')),
              onPressed: () {
                HapticFeedback.selectionClick();
                startQuiz(context, s.builder.pyqForTopic(subject: v.subject, topic: v.topic));
              },
            ),
        ]),
      ]),
    );
  }
}

class _StrongTopic extends StatelessWidget {
  final TopicVerdict v;
  const _StrongTopic({required this.v});

  @override
  Widget build(BuildContext context) {
    final topic = context.scope.repo.topic(v.subject, v.topic);
    if (topic == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        const Icon(Icons.verified, size: 18, color: BrandColors.correct),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            context.tr('${topic.name.hi}: ${v.sessionCorrect}/${v.sessionAttempts} — शानदार, ऐसे ही जारी रखें! ✅',
                '${topic.name.en}: ${v.sessionCorrect}/${v.sessionAttempts} — great work, keep it up! ✅'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}
