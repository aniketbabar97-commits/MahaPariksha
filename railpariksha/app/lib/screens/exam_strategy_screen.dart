import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

const _stageColors = [
  BrandColors.sky,
  BrandColors.skyLight,
  BrandColors.saffron,
  BrandColors.correct,
];

/// "Exam Strategy & Pattern" — a static, researched reference screen that
/// spells out exactly how the student's chosen exam actually works: its real
/// multi-stage selection process, how negative marking plays out with a
/// worked example using THIS exam's own numbers, a time-budget suggestion,
/// and concrete tactical tips. Nothing in the mock-test UI explains this
/// directly today -- students currently have to infer it.
class ExamStrategyScreen extends StatelessWidget {
  final Exam exam;
  const ExamStrategyScreen({super.key, required this.exam});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final strategy = context.scope.repo.strategy(exam.id);

    if (strategy == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('परीक्षा रणनीति', 'Exam strategy'))),
        body: EmptyState(
          icon: Icons.fact_check,
          text: context.tr('इस परीक्षा की रणनीति जल्द ही आ रही है।', 'Strategy guide for this exam is coming soon.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('परीक्षा रणनीति व पैटर्न', 'Exam strategy & pattern'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: BrandColors.heroGradient, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.route, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(exam.name.of(lang),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                      context.tr('चयन प्रक्रिया, निगेटिव मार्किंग व समय प्रबंधन',
                          'Selection process, negative marking & time management'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
          SectionTitle(context.tr('चयन प्रक्रिया 🛤️', 'Selection process 🛤️')),
          _StageTimeline(stages: strategy.stages, lang: lang),
          SectionTitle(context.tr('निगेटिव मार्किंग — उदाहरण 🧮', 'Negative marking — worked example 🧮')),
          _NegativeMarkingCard(exam: exam, lang: lang),
          SectionTitle(context.tr('समय प्रबंधन ⏱️', 'Time budgeting ⏱️')),
          _TimeBudgetCard(exam: exam, lang: lang),
          SectionTitle(context.tr('ज़रूरी टिप्स 💡', 'Tactical tips 💡')),
          for (final tip in strategy.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                color: BrandColors.saffron.withValues(alpha: 0.08),
                child: ListTile(
                  leading: const Icon(Icons.lightbulb, color: BrandColors.saffron),
                  title: Text(tip.of(lang), style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          SectionTitle(context.tr('कटऑफ के बारे में सच ⚖️', 'The truth about cutoffs ⚖️')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: Theme.of(context).hintColor),
                const SizedBox(width: 10),
                Expanded(child: Text(strategy.cutoffNote.of(lang), style: const TextStyle(height: 1.5))),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
                'यह जानकारी सार्वजनिक स्रोतों से शोध करके बनाई गई है। आधिकारिक व नवीनतम जानकारी के लिए संबंधित भर्ती बोर्ड की वेबसाइट देखें।',
                'This information is researched from public sources. Refer to the relevant recruitment board\'s official website for the latest and authoritative details.'),
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StageTimeline extends StatelessWidget {
  final List<StrategyStage> stages;
  final String lang;
  const _StageTimeline({required this.stages, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < stages.length; i++)
          _StageRow(index: i, isLast: i == stages.length - 1, stage: stages[i], lang: lang),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  final int index;
  final bool isLast;
  final StrategyStage stage;
  final String lang;
  const _StageRow({required this.index, required this.isLast, required this.stage, required this.lang});

  @override
  Widget build(BuildContext context) {
    final color = _stageColors[index % _stageColors.length];
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
                child: Text('${index + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
          ),
          if (!isLast) Expanded(child: Container(width: 3, color: color.withValues(alpha: 0.3))),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              color: color.withValues(alpha: 0.07),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(stage.title.of(lang), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
                  const SizedBox(height: 6),
                  Text(stage.detail.of(lang), style: const TextStyle(height: 1.45, fontSize: 13.5)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Computes the worked example live from the exam's real paperQuestions/
/// paperMinutes/negative instead of storing it as static text, so it can
/// never drift out of sync with the taxonomy's own numbers.
class _NegativeMarkingCard extends StatelessWidget {
  final Exam exam;
  final String lang;
  const _NegativeMarkingCard({required this.exam, required this.lang});

  @override
  Widget build(BuildContext context) {
    final q = exam.paperQuestions ?? 100;
    final neg = exam.negative;
    final fracLabel = neg == 0
        ? context.tr('कोई निगेटिव मार्किंग नहीं', 'No negative marking')
        : '1/${(1 / neg).round()}';

    // Example attempt: a realistic ~80% attempt rate with a 75% hit-rate on
    // attempted questions -- illustrative, not a prediction of any real score.
    final attempted = (q * 0.8).round();
    final correct = (attempted * 0.75).round();
    final wrong = attempted - correct;
    final unattempted = q - attempted;
    final score = correct - wrong * neg;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: BrandColors.wrong.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(
                  context.tr('हर गलत जवाब पर $fracLabel अंक कटेगा', '$fracLabel mark deducted per wrong answer'),
                  style: const TextStyle(color: BrandColors.wrong, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ]),
          if (neg > 0) ...[
            const SizedBox(height: 14),
            Text(
                context.tr(
                    'मान लीजिए इस पेपर ($q प्रश्न) में आप $attempted प्रश्न हल करते हैं, जिनमें से $correct सही व $wrong गलत होते हैं ($unattempted प्रश्न खाली):',
                    'Suppose you attempt $attempted of this paper\'s $q questions, getting $correct right and $wrong wrong ($unattempted left unattempted):'),
                style: const TextStyle(height: 1.5, fontSize: 13.5)),
            const SizedBox(height: 10),
            _ScoreRow(context.tr('सही उत्तर', 'Correct answers'), '+$correct', BrandColors.correct),
            _ScoreRow(context.tr('गलत उत्तर का नुकसान', 'Penalty for wrong answers'),
                '-${(wrong * neg).toStringAsFixed(2)}', BrandColors.wrong),
            const Divider(height: 18),
            _ScoreRow(context.tr('अंतिम स्कोर', 'Final score'), score.toStringAsFixed(2), BrandColors.sky, bold: true),
            const SizedBox(height: 10),
            Text(
                context.tr(
                    'यानी हर गलत जवाब सिर्फ़ उस 1 अंक को नहीं, बल्कि आपके स्कोर से $fracLabel अतिरिक्त अंक भी छीनता है — किसी प्रश्न को बिना किसी आधार के बेतरतीब छूना अक्सर खाली छोड़ने से बुरा साबित होता है।',
                    'So every wrong answer costs more than just that 1 mark — it also strips an extra $fracLabel mark from your score. A pure, baseless guess is often worse than leaving the question unattempted.'),
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5, height: 1.4)),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                  context.tr('इस परीक्षा में गलत जवाब पर कोई अंक नहीं कटता — सोच-समझकर अंदाज़ा लगाना फ़ायदेमंद हो सकता है।',
                      'No marks are deducted for wrong answers in this exam — an educated guess can only help, never hurt.'),
                  style: const TextStyle(height: 1.45, fontSize: 13.5)),
            ),
        ]),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _ScoreRow(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

class _TimeBudgetCard extends StatelessWidget {
  final Exam exam;
  final String lang;
  const _TimeBudgetCard({required this.exam, required this.lang});

  @override
  Widget build(BuildContext context) {
    final q = exam.paperQuestions;
    final min = exam.paperMinutes;
    if (q == null || min == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.tr('इस परीक्षा के लिए समय-सीमा की जानकारी उपलब्ध नहीं है।', 'Time-limit details are not available for this exam.')),
        ),
      );
    }
    final totalSeconds = min * 60;
    final reviewMinutes = (min * 0.08).round().clamp(3, 15);
    final workMinutes = min - reviewMinutes;
    final secPerQ = (workMinutes * 60) / q;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: _StatBox(
                  label: context.tr('कुल प्रश्न', 'Total questions'), value: '$q', icon: Icons.quiz, color: BrandColors.sky),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBox(
                  label: context.tr('कुल समय', 'Total time'),
                  value: context.tr('$min मिनट', '$min min'),
                  icon: Icons.timer,
                  color: BrandColors.saffron),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _StatBox(
                  label: context.tr('प्रति प्रश्न', 'Per question'),
                  value: '~${secPerQ.round()}s',
                  icon: Icons.speed,
                  color: BrandColors.correct),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBox(
                  label: context.tr('रिवीज़न के लिए', 'Reserved for review'),
                  value: context.tr('$reviewMinutes मिनट', '$reviewMinutes min'),
                  icon: Icons.fact_check,
                  color: BrandColors.wrong),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
              context.tr(
                  'सुझाव: पहले $workMinutes मिनट में सभी प्रश्नों को एक बार हल करने की कोशिश करें (लगभग ${secPerQ.round()} सेकंड/प्रश्न की रफ़्तार से), और बचे हुए $reviewMinutes मिनट मार्क किए गए व छूटे प्रश्नों की समीक्षा के लिए रखें — कुल ${totalSeconds ~/ 60} मिनट में।',
                  'Suggestion: aim to attempt every question once in the first $workMinutes minutes (about ${secPerQ.round()} seconds/question), and reserve the remaining $reviewMinutes minutes to revisit flagged or skipped questions — all within the $min-minute limit.'),
              style: const TextStyle(height: 1.5, fontSize: 13.5)),
        ]),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
        ]),
      );
}
