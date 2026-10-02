import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'ca_archive_screen.dart';
import 'quiz_screen.dart';

/// Topic-flavoured icon for a digest card -- purely decorative, so an unknown
/// topic id just falls back to the generic current-affairs icon instead of
/// erroring.
IconData _topicIcon(String topic) => switch (topic) {
      'sports_news' => Icons.sports_cricket,
      'awards_news' => Icons.emoji_events_outlined,
      'schemes' => Icons.account_balance_outlined,
      'appointments' => Icons.badge_outlined,
      'sci_tech_news' => Icons.science_outlined,
      'banking_finance' => Icons.currency_rupee,
      'railway_current_affairs' => Icons.train_outlined,
      'international' => Icons.public,
      _ => Icons.newspaper_outlined,
    };

/// Daily Current Affairs digest: a readable news-brief, not a quiz. Shows the
/// most recent day's auto-drafted current-affairs facts as short bilingual
/// cards with a source link each -- the explanation text already written for
/// the matching MCQ, read on its own as a news brief rather than as an
/// answer key. A quiz for the same day, and the full dated archive, are one
/// tap away for anyone who wants to test themselves instead of just reading.
class CaDigestScreen extends StatefulWidget {
  const CaDigestScreen({super.key});

  @override
  State<CaDigestScreen> createState() => _CaDigestScreenState();
}

class _CaDigestScreenState extends State<CaDigestScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final lang = context.lang;
    final byDate = s.builder.currentAffairsByDate();
    final dates = byDate.keys.toList();

    if (dates.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('करेंट अफेयर्स डाइजेस्ट 📰', 'Current Affairs digest 📰'))),
        body: EmptyState(
          icon: Icons.newspaper_outlined,
          text: context.tr('आज का डाइजेस्ट जल्द आ रहा है — रोज़ नए अपडेट जुड़ेंगे।',
              "Today's digest is coming soon -- new ones get added daily."),
        ),
      );
    }

    final date = (_selected != null && dates.contains(_selected)) ? _selected! : dates.first;
    final items = byDate[date]!;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('करेंट अफेयर्स डाइजेस्ट 📰', 'Current Affairs digest 📰'))),
      body: Column(children: [
        if (dates.length > 1)
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              scrollDirection: Axis.horizontal,
              itemCount: dates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = dates[i];
                final selected = d == date;
                return ChoiceChip(
                  label: Text(formatCaDate(d).of(lang)),
                  selected: selected,
                  selectedColor: BrandColors.saffron.withValues(alpha: 0.25),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _selected = d);
                  },
                );
              },
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(context.tr('आज जाननें लायक ${items.length} बातें', '${items.length} things worth knowing today'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(formatCaDate(date).of(lang), style: TextStyle(color: Theme.of(context).hintColor)),
              const SizedBox(height: 14),
              for (final q in items) _DigestCard(q: q, lang: lang),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(context.tr('इस दिन की क्विज़ लें', "Take this day's quiz")),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  startQuiz(context, s.builder.currentAffairsQuiz(date));
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(context.tr('पुराने दिन ब्राउज़ करें', 'Browse past days')),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  push(context, (_) => const CaArchiveScreen());
                },
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _DigestCard extends StatelessWidget {
  final Question q;
  final String lang;
  const _DigestCard({required this.q, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_topicIcon(q.topic), color: BrandColors.saffron, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.scope.repo.topic(q.subject, q.topic)?.name.of(lang) ?? q.topic,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: BrandColors.saffron, fontSize: 13),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(q.explanation.of(lang), style: const TextStyle(fontSize: 15, height: 1.5)),
            if (q.src != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  launchUrl(Uri.parse(q.src!), mode: LaunchMode.externalApplication);
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.open_in_new, size: 15, color: BrandColors.skyLight),
                  const SizedBox(width: 4),
                  Text(context.tr('स्रोत देखें', 'Read source'),
                      style: const TextStyle(color: BrandColors.skyLight, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
