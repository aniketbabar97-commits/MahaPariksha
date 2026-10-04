import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';

import '../core/ads.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/progress.dart';
import '../logic/leaderboard_service.dart';
import '../logic/mock_analysis.dart';
import '../logic/next_steps.dart';
import '../logic/percentile.dart';
import '../logic/quiz_builder.dart';
import '../widgets/common.dart';
import '../widgets/explanation_player.dart';
import '../widgets/share_card.dart';
import 'next_steps_card.dart';
import 'quiz_screen.dart';

class ResultsScreen extends StatefulWidget {
  final QuizSpec spec;
  final List<int?> answers;
  final int xpEarned;
  final Duration elapsed;
  final int speedScore;

  /// Time spent on each question, parallel to [answers]. Null for callers
  /// that don't track it.
  final List<Duration>? timePerQuestion;
  const ResultsScreen({
    super.key,
    required this.spec,
    required this.answers,
    required this.xpEarned,
    required this.elapsed,
    required this.speedScore,
    this.timePerQuestion,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  /// This exam's previous mock, captured before this one is recorded.
  MockResult? _prevMock;

  int get correct => [for (var i = 0; i < widget.answers.length; i++) widget.answers[i] == widget.spec.questions[i].answer]
      .where((c) => c)
      .length;
  int get attempted => widget.answers.where((a) => a != null).length;
  int get wrong => attempted - correct;
  double get score => correct - wrong * widget.spec.negative;

  @override
  void initState() {
    super.initState();
    if (widget.spec.mode == QuizMode.mock) {
      final p = AppScope.read(context).progress;
      for (final m in p.mocks.reversed) {
        if (m.examId == (p.examId ?? '') && m.total > 0) {
          _prevMock = m;
          break;
        }
      }
    }
    // Recording notifies Progress listeners (AppScope), which must not happen
    // while this screen is still in its first build.
    if (widget.spec.mode == QuizMode.mock) WidgetsBinding.instance.addPostFrameCallback((_) => _recordMock());
    // Practice-style sessions only: a mock's results may already be showing
    // an interstitial ad, and stacking two interruptions would sour the moment.
    if (widget.spec.instantFeedback && widget.spec.mode != QuizMode.speed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskForReview());
    }
  }

  Future<void> _maybeAskForReview() async {
    final total = widget.spec.questions.length;
    if (!mounted || total < 5) return;
    final p = AppScope.read(context).progress;
    if (!p.shouldAskForReview(sessionScore: correct / total)) return;
    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      // Let the score land first; the ask should follow the good moment.
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      p.markReviewAsked();
      await review.requestReview();
    } catch (_) {
      // No Play Store / services on this device: a rating ask is optional.
    }
  }

  void _recordMock() {
    if (!mounted) return;
    final p = AppScope.read(context).progress;
    p.recordMock(MockResult(today(), p.examId ?? '', score, widget.spec.questions.length));
    // Opt-in only: a device without a chosen leaderboard name has never opened the
    // leaderboard screen, so it never silently starts appearing on one.
    if (p.examId != null && p.leaderboardName != null) {
      LeaderboardService.submitScore(
        examId: p.examId!,
        deviceId: p.ensureDeviceId(),
        name: p.leaderboardName!,
        score: score,
        total: widget.spec.questions.length,
      );
    }
    // Natural break point: results are already recorded, so showing (or
    // skipping, if not preloaded in time) the ad here never blocks or
    // delays anything the user is waiting on. Frequency-capped per
    // InterstitialAdManager.shouldShowForMockCount -- see its doc comment.
    if (!p.removedAds && InterstitialAdManager.shouldShowForMockCount(p.mocks.length)) {
      InterstitialAdManager.showIfReady();
    }
  }

  String _headline(BuildContext context, double pct) {
    if (pct >= 0.9) return context.tr('शानदार! तुम वंदे भारत की रफ़्तार से चल रहे हो! 🏆', 'Outstanding! You\'re running at Vande Bharat speed! 🏆');
    if (pct >= 0.7) return context.tr('बढ़िया प्रदर्शन! ऐसे ही आगे बढ़ते रहें! 🚀', 'Great work! Keep soaring! 🚀');
    if (pct >= 0.4) return context.tr('अच्छी शुरुआत! थोड़ा और अभ्यास करें 💪', 'Good start! A bit more practice 💪');
    return context.tr('हर गलती एक सबक है। दोबारा कोशिश करें! 🔥', 'Every mistake is a lesson. Try again! 🔥');
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final total = spec.questions.length;
    final isSpeed = spec.mode == QuizMode.speed;
    final pct = isSpeed ? (widget.speedScore / 15).clamp(0.0, 1.0) : (total == 0 ? 0.0 : correct / total);
    final lang = context.lang;
    final p = context.scope.progress;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('परिणाम 🏁', 'Results 🏁'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: BrandColors.heroGradient, borderRadius: BorderRadius.circular(24)),
            child: Column(children: [
              GoalRing(
                progress: pct,
                size: 140,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CountUpText(isSpeed ? widget.speedScore : correct,
                      format: isSpeed ? null : (v) => '$v/$total',
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  CountUpText((pct * 100).round(),
                      format: (v) => isSpeed ? context.tr('60 सेकंड में', 'in 60 sec') : '$v%',
                      style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              const SizedBox(height: 16),
              Text(_headline(context, pct),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
                _pill('+${widget.xpEarned} XP', Icons.bolt),
                if (!isSpeed) _pill('${widget.elapsed.inMinutes}m ${widget.elapsed.inSeconds % 60}s', Icons.timer),
                if (isSpeed) _pill(context.tr('सर्वश्रेष्ठ ${p.bestSpeed}', 'Best ${p.bestSpeed}'), Icons.emoji_events),
                if (spec.negative > 0)
                  _pill(context.tr('अंक ${score.toStringAsFixed(2)}', 'Score ${score.toStringAsFixed(2)}'), Icons.calculate),
                if (_prevMock != null && total > 0)
                  () {
                    final delta = ((score / total - _prevMock!.score / _prevMock!.total) * 100).round();
                    final sign = delta > 0 ? '+' : (delta < 0 ? '−' : '±');
                    return _pill(context.tr('पिछले मॉक से $sign${delta.abs()}%', '$sign${delta.abs()}% vs last mock'),
                        delta >= 0 ? Icons.trending_up : Icons.trending_down);
                  }(),
                if (spec.mode == QuizMode.mock && total > 0)
                  _pill(context.tr('अनुमानित टॉप ${100 - estimatedPercentile(correct / total)}%',
                      'Est. top ${100 - estimatedPercentile(correct / total)}%'), Icons.leaderboard),
              ]),
            ]),
          ),
          if (spec.mode == QuizMode.mock && total > 0) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.info_outline, size: 14, color: Theme.of(context).hintColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  context.tr(
                      'यह एक सांख्यिकीय अनुमान है, असली उपयोगकर्ताओं की लाइव रैंकिंग नहीं',
                      'A statistical estimate, not a live ranking against real users'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor),
                ),
              ),
            ]),
          ],
          if (spec.negative > 0) ...[
            const SizedBox(height: 10),
            Text(
              context.tr('नकारात्मक अंकन: हर गलत उत्तर पर −${spec.negative}. सही $correct · गलत $wrong · छोड़े ${total - attempted}',
                  'Negative marking: −${spec.negative} per wrong. Correct $correct · Wrong $wrong · Skipped ${total - attempted}'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share),
                label: Text(context.tr('शेयर करें', 'Share')),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  final scoreStr = isSpeed ? '${widget.speedScore}' : '$correct/$total';
                  final title = lang == 'hi' ? spec.titleHi : spec.titleEn;
                  shareScoreCard(
                    context,
                    card: ScoreShareCard(
                      headline: context.tr('मैंने $title में यह स्कोर हासिल किया!', 'I scored this on $title!'),
                      scoreText: scoreStr,
                      scoreSub: isSpeed
                          ? context.tr('60 सेकंड में सही उत्तर', 'correct answers in 60 sec')
                          : context.tr('सही उत्तर', 'correct answers'),
                      footer: context.tr('आप कितने लाएंगे? 🔥', 'Can you beat it? 🔥'),
                      icon: isSpeed ? Icons.bolt : Icons.emoji_events,
                    ),
                    text: context.tr(
                        'मैंने RailPariksha ऐप पर $title में $scoreStr अंक हासिल किए! 🔥 आप कितने लाएंगे? $kPlayUrl',
                        'I scored $scoreStr in $title on RailPariksha! 🔥 Can you beat it? $kPlayUrl'),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
                child: Text(context.tr('पूर्ण', 'Done')),
              ),
            ),
          ]),
          if (!isSpeed && wrong > 0) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.replay),
              label: Text(context.tr('गलत हुए $wrong प्रश्न तुरंत दोबारा हल करें', 'Retry the $wrong you got wrong now')),
              onPressed: () {
                HapticFeedback.selectionClick();
                final missed = [
                  for (var i = 0; i < total; i++)
                    if (widget.answers[i] != null && widget.answers[i] != spec.questions[i].answer) spec.questions[i],
                ];
                startQuiz(context, QuizSpec(QuizMode.practice, missed, 'गलत प्रश्न दोबारा', 'Retry mistakes'));
              },
            ),
          ],
          if (spec.mode != QuizMode.placement && total > 0) ...[
            const SizedBox(height: 12),
            NextStepsCard(steps: NextSteps.from(spec.questions, widget.answers, context.scope.builder.topicStats())),
          ],
          if (!spec.instantFeedback && total > 0)
            _AnalysisSection(analysis: MockAnalysis.from(spec, widget.answers, widget.timePerQuestion), lang: lang),
          if (!isSpeed) ...[
            SectionTitle(context.tr('उत्तरों की समीक्षा 🔍', 'Answer review 🔍')),
            for (var i = 0; i < total; i++)
              _ReviewTile(
                index: i,
                spec: spec,
                answer: widget.answers[i],
                lang: lang,
                time: widget.timePerQuestion != null && i < widget.timePerQuestion!.length ? widget.timePerQuestion![i] : null,
              ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String t, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: BrandColors.sunrise, size: 16),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      );
}

String _fmtDuration(Duration d) => d.inMinutes > 0 ? '${d.inMinutes}m ${d.inSeconds % 60}s' : '${d.inSeconds}s';

class _AnalysisSection extends StatelessWidget {
  final MockAnalysis analysis;
  final String lang;
  const _AnalysisSection({required this.analysis, required this.lang});

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final repo = context.scope.repo;
    final hint = Theme.of(context).hintColor;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(context.tr('प्रदर्शन विश्लेषण 📊', 'Performance analysis 📊')),
      if (a.subjects.length > 1)
        for (final s in a.subjects)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(repo.subject(s.subject)?.name.of(lang) ?? s.subject,
                        style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                  ),
                  Text('${s.correct}/${s.total}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: s.total == 0 ? 0 : s.correct / s.total,
                    minHeight: 8,
                    color: s.accuracy() >= 0.7
                        ? BrandColors.correct
                        : (s.accuracy() >= 0.4 ? BrandColors.saffron : BrandColors.wrong),
                    backgroundColor: hint.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    context.tr('प्रयास ${s.attempted}', 'Attempted ${s.attempted}'),
                    if (s.attempted > 0) context.tr('सटीकता ${(s.accuracy() * 100).round()}%', 'Accuracy ${(s.accuracy() * 100).round()}%'),
                    if (a.negative > 0) context.tr('शुद्ध ${s.net(a.negative).toStringAsFixed(2)}', 'Net ${s.net(a.negative).toStringAsFixed(2)}'),
                    if (s.time > Duration.zero) _fmtDuration(s.time),
                  ].join(' · '),
                  style: TextStyle(fontSize: 12.5, color: hint),
                ),
              ]),
            ),
          ),
      if (a.negative > 0 && a.wrong > 0)
        _InsightTile(
          icon: Icons.remove_circle_outline,
          color: BrandColors.wrong,
          text: context.tr(
              'नकारात्मक अंकन से आपके ${a.marksLostToNegative.toStringAsFixed(2)} अंक कटे (${a.wrong} गलत उत्तर)।',
              'Negative marking cost you ${a.marksLostToNegative.toStringAsFixed(2)} marks (${a.wrong} wrong answers).'),
        ),
      if (a.tip == StrategyTip.overAttempting)
        _InsightTile(
          icon: Icons.lightbulb_outline,
          color: BrandColors.saffron,
          text: context.tr(
              'आधे से ज़्यादा प्रयास गलत रहे। जिस प्रश्न में आप कम से कम 2 विकल्प नहीं हटा पा रहे, उसे छोड़ दें — अंदाज़ा लगाना महंगा पड़ रहा है।',
              'Over half your attempts were wrong. Skip any question where you can\'t eliminate at least 2 options — guessing is costing you marks.'),
        ),
      if (a.tip == StrategyTip.underAttempting)
        _InsightTile(
          icon: Icons.trending_up,
          color: BrandColors.correct,
          text: context.tr(
              'आपकी सटीकता बहुत अच्छी है, पर कई प्रश्न छोड़े। अगर 2 विकल्पों तक पहुँच जाएँ तो उत्तर दें — इस अंकन में यह औसतन फ़ायदेमंद है।',
              'Your accuracy is excellent but you skipped a lot. When you can narrow it to 2 options, answer — with this marking scheme that pays off on average.'),
        ),
      if (a.avgTime != null)
        _InsightTile(
          icon: Icons.timer_outlined,
          color: BrandColors.skyLight,
          text: a.targetPace != null
              ? context.tr('औसत ${_fmtDuration(a.avgTime!)} प्रति प्रश्न · परीक्षा की गति ${_fmtDuration(a.targetPace!)} प्रति प्रश्न',
                  'Avg ${_fmtDuration(a.avgTime!)} per question · exam pace ${_fmtDuration(a.targetPace!)} per question')
              : context.tr('औसत ${_fmtDuration(a.avgTime!)} प्रति प्रश्न', 'Avg ${_fmtDuration(a.avgTime!)} per question'),
        ),
      if (a.slowest.isNotEmpty)
        _InsightTile(
          icon: Icons.hourglass_bottom,
          color: BrandColors.saffron,
          text: context.tr('सबसे ज़्यादा समय लगा: ', 'Took the longest: ') +
              a.slowest.map((i) => context.tr('प्र.${i + 1}', 'Q${i + 1}')).join(', '),
        ),
    ]);
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InsightTile({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
          ]),
        ),
      );
}

class _ReviewTile extends StatelessWidget {
  final int index;
  final QuizSpec spec;
  final int? answer;
  final String lang;
  final Duration? time;
  const _ReviewTile({required this.index, required this.spec, required this.answer, required this.lang, this.time});

  @override
  Widget build(BuildContext context) {
    final q = spec.questions[index];
    final ok = answer == q.answer;
    final opts = q.options(lang);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        leading: Icon(answer == null ? Icons.remove_circle_outline : (ok ? Icons.check_circle : Icons.cancel),
            color: answer == null ? Colors.grey : (ok ? BrandColors.correct : BrandColors.wrong)),
        title: Text('${index + 1}. ${q.text.of(lang)}', maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: time == null || time!.inSeconds == 0
            ? null
            : Text('⏱ ${_fmtDuration(time!)}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.text.of(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (answer != null && !ok)
            Text('✗ ${opts[answer!]}', style: const TextStyle(color: BrandColors.wrong)),
          Text('✓ ${opts[q.answer]}', style: const TextStyle(color: BrandColors.correct, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ExplanationPlayer(text: q.explanation.of(lang)),
          if (q.hook != null) ...[
            const SizedBox(height: 6),
            Text('💡 ${q.hook!.of(lang)}', style: const TextStyle(height: 1.5)),
          ],
        ],
      ),
    );
  }
}
