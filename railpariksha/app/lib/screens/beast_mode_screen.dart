import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../logic/quiz_builder.dart';
import '../widgets/celebrate.dart';
import '../widgets/common.dart';

/// A question wrong in a row this many times in a row ends the sprint early — "knocked out".
/// Telegraphed one step ahead in the HUD (see [_KnockoutWarning]).
const _kKnockoutAt = 3;

const _labelsHi = ['अ', 'ब', 'क', 'ड'];
const _labelsEn = ['A', 'B', 'C', 'D'];

/// Multiplier tiers, keyed by correct-answers-in-a-row. Any wrong answer resets the streak
/// to 0, which resets this back to 1x — that reset is the core Beast Mode tension.
double _multiplierFor(int streak) {
  if (streak >= 10) return 2.0;
  if (streak >= 6) return 1.5;
  if (streak >= 3) return 1.2;
  return 1.0;
}

/// Launches Beast Mode with [spec] (built by [QuizBuilder.beast]), matching [startQuiz]'s
/// empty-pool guard in quiz_screen.dart.
void startBeastMode(BuildContext context, QuizSpec spec, int seconds) {
  if (spec.questions.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('अभी पर्याप्त प्रश्न नहीं हैं। जल्द आ रहे हैं!', 'Not enough questions yet. Coming soon!'))));
    return;
  }
  HapticFeedback.selectionClick();
  push(context, (_) => BeastModeScreen(spec: spec, seconds: seconds));
}

class BeastModeScreen extends StatefulWidget {
  final QuizSpec spec;
  final int seconds;
  const BeastModeScreen({super.key, required this.spec, required this.seconds});

  @override
  State<BeastModeScreen> createState() => _BeastModeScreenState();
}

class _BeastModeScreenState extends State<BeastModeScreen> {
  late String qLang;
  late List<Question> queue;
  int qi = 0;
  Timer? timer;
  late int remaining;

  double score = 0;
  int streak = 0;
  int bestStreakRun = 0;
  int consecutiveWrong = 0;
  int correctCount = 0;
  int wrongCount = 0;
  int xpEarned = 0;

  bool _locked = false;
  int? _flashAnswer;
  bool _finished = false;
  bool _dialogOpen = false;
  // Beast Mode already earns real per-question Rewards via recordAnswer
  // (same as Practice/Speed), but never used anything beyond .xp -- a
  // level-up/streak/goal mid-sprint got zero payoff. Collected here and
  // celebrated once in _finish(), before the results sheet, rather than
  // popping a dialog mid-sprint (which the 280ms answer-lock window and the
  // countdown timer are not built to tolerate).
  Reward? _notable;

  QuizSpec get spec => widget.spec;
  Question get q => queue[qi];
  double get multiplier => _multiplierFor(streak);

  @override
  void initState() {
    super.initState();
    qLang = AppScope.read(context).progress.lang;
    remaining = widget.seconds;
    queue = List.of(spec.questions)..shuffle();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => remaining--);
      if (remaining <= 0) _finish();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _select(int i) {
    if (_locked || _finished) return;
    final correct = i == q.answer;
    final p = AppScope.read(context).progress;
    final r = p.recordAnswer(q.id, correct);
    xpEarned += r.xp;
    if (r.levelUp || r.streakMilestone != null || r.goalCompleted) _notable = r;
    setState(() {
      _locked = true;
      _flashAnswer = i;
      if (correct) {
        streak++;
        consecutiveWrong = 0;
        correctCount++;
        if (streak > bestStreakRun) bestStreakRun = streak;
        score += 1.0 * multiplier;
      } else {
        wrongCount++;
        consecutiveWrong++;
        streak = 0;
        score -= spec.negative;
      }
    });
    if (correct) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.vibrate();
    }
    Future.delayed(const Duration(milliseconds: 280), _afterAnswerDelay);
  }

  /// Split out of [_select]'s delayed callback so [_confirmExit] can also call
  /// this once its dialog closes, if the 280ms window landed while that dialog
  /// was open -- otherwise a back-press right after a knockout-triggering wrong
  /// answer could pop a results bottom sheet on top of the still-open "Stop the
  /// sprint?" dialog (two stacked modals, confusing flash for the user).
  void _afterAnswerDelay() {
    // _locked guard makes this safe to call twice for the same answer (once
    // from the delayed Future, once from _confirmExit re-checking after its
    // dialog closes) -- whichever runs first flips _locked/_finished, so the
    // second call becomes a no-op.
    if (!mounted || _finished || _dialogOpen || !_locked) return;
    if (consecutiveWrong >= _kKnockoutAt) {
      _finish(knockedOut: true);
      return;
    }
    setState(() {
      _locked = false;
      _flashAnswer = null;
      if (qi + 1 < queue.length) {
        qi++;
      } else {
        // Exhausted the pool before the timer ran out: reshuffle and keep going,
        // nudging the previous last question out of the very next slot.
        final last = queue[qi];
        queue = List.of(spec.questions)..shuffle();
        if (queue.length > 1 && queue.first == last) {
          final tmp = queue[0];
          queue[0] = queue[1];
          queue[1] = tmp;
        }
        qi = 0;
      }
    });
  }

  Future<void> _finish({bool knockedOut = false}) async {
    if (_finished) return;
    // Flips canPop (see PopScope below) to true via rebuild, so the results sheet's own
    // "Play again"/"Done" pops go straight through instead of hitting the in-sprint exit
    // confirmation — the run is already recorded by the time either button is tappable.
    setState(() => _finished = true);
    timer?.cancel();
    final p = AppScope.read(context).progress;
    // Captured before recordBeast updates beastBestScore -- comparing against
    // the post-update value (p.beastBestScore == score) can't tell a genuine
    // new best from merely tying the already-recorded one.
    final previousBest = p.beastBestScore;
    p.recordBeast(score, bestStreakRun);
    if (_notable != null && mounted) await celebrate(context, _notable!);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetCtx) => _BeastResultsSheet(
        score: score,
        correct: correctCount,
        wrong: wrongCount,
        bestStreakRun: bestStreakRun,
        xpEarned: xpEarned,
        knockedOut: knockedOut,
        isNewBest: score > previousBest,
        // Both callbacks pop via this State's own (still-mounted) `context` rather than the
        // sheet's — by the time either is tappable the sheet is a separate, shorter-lived
        // route, and chaining pops off it after it starts closing is asking for trouble.
        onPlayAgain: () {
          Navigator.pop(sheetCtx);
          Navigator.pop(context);
          startBeastMode(context, context.scope.builder.beast(seconds: widget.seconds), widget.seconds);
        },
        onDone: () {
          Navigator.pop(sheetCtx);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<bool> _confirmExit() async {
    if (correctCount == 0 && wrongCount == 0) return true;
    _dialogOpen = true;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('स्प्रिंट रोकना है?', 'Stop the sprint?')),
        content: Text(ctx.tr('अभी तक का स्कोर सेव नहीं होगा।', "This run's score won't be saved.")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('जारी रखें', 'Continue'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('रोकें', 'Stop'))),
        ],
      ),
    );
    _dialogOpen = false;
    // If the 280ms post-answer window elapsed while this dialog was open,
    // _afterAnswerDelay bailed out without advancing/finishing -- run it now
    // that the dialog is closed (idempotent if it already ran on its own).
    _afterAnswerDelay();
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final options = q.options(qLang);
    final labels = qLang == 'en' ? _labelsEn : _labelsHi;

    return PopScope(
      // Once the run is finished, let pops (e.g. the results sheet's own buttons, or the
      // system back button after that sheet is up) go through without a confirmation —
      // there is nothing left to lose by leaving.
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        timer?.cancel();
        timer = null;
        final wantsExit = await _confirmExit();
        // _confirmExit() can itself trigger _finish() (a deferred knockout that
        // landed while its dialog was open, see _afterAnswerDelay) -- in that
        // case the results sheet is already showing on top of this screen, so
        // don't ALSO pop here: that would immediately close the sheet we just
        // opened instead of the screen underneath it.
        if (wantsExit && context.mounted && !_finished) {
          Navigator.pop(context);
        } else if (!wantsExit && !_finished) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (!mounted) return;
            setState(() => remaining--);
            if (remaining <= 0) _finish();
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1320),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(qLang == 'en' ? 'Beast Mode ⚡' : 'बीस्ट मोड ⚡',
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                GoalRing(
                  progress: remaining / widget.seconds,
                  size: 74,
                  child: Text('$remaining',
                      style: TextStyle(
                          color: remaining <= 10 ? BrandColors.wrong : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.bolt, color: BrandColors.saffron, size: 20),
                      const SizedBox(width: 4),
                      Text(score.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 10),
                      _MultiplierChip(multiplier: multiplier),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.local_fire_department, color: BrandColors.saffron, size: 16),
                      const SizedBox(width: 2),
                      Text(context.tr('स्ट्रीक $streak', 'Streak $streak'),
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ]),
                ),
              ]),
            ),
            if (consecutiveWrong == _kKnockoutAt - 1) const _KnockoutWarning(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: ListView(
                  key: ValueKey('$qi-${identityHashCode(queue)}'),
                  padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.lg),
                  children: [
                    Text(q.text.of(qLang),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.4)),
                    const SizedBox(height: Spacing.lg),
                    for (var i = 0; i < options.length; i++)
                      _BeastOptionTile(
                        label: labels[i],
                        text: options[i],
                        state: _optionState(i),
                        onTap: () => _select(i),
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  _BeastOptState _optionState(int i) {
    if (_flashAnswer == null) return _BeastOptState.idle;
    if (i == q.answer) return _BeastOptState.correct;
    if (i == _flashAnswer) return _BeastOptState.wrong;
    return _BeastOptState.dim;
  }
}

class _MultiplierChip extends StatelessWidget {
  final double multiplier;
  const _MultiplierChip({required this.multiplier});

  @override
  Widget build(BuildContext context) {
    final hot = multiplier > 1.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hot ? BrandColors.saffron : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('${multiplier}x',
          style: TextStyle(
              color: hot ? BrandColors.sky : Colors.white70, fontWeight: FontWeight.w900, fontSize: 13)),
    );
  }
}

class _KnockoutWarning extends StatelessWidget {
  const _KnockoutWarning();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.sm),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: BrandColors.wrong.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BrandColors.wrong, width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded, color: BrandColors.wrong, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                context.tr('एक और गलती और आप बाहर! ⚠️', 'One more wrong and you\'re out! ⚠️'),
                style: const TextStyle(color: BrandColors.wrong, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ]),
        ),
      );
}

enum _BeastOptState { idle, correct, wrong, dim }

/// A leaner sibling of quiz_screen.dart's private `_OptionTile`: same visual language
/// (border/bg/icon per state, Corners radius) but without the "selected while waiting for
/// feedback" state — Beast Mode scores the instant you tap, so it only ever needs
/// idle/correct/wrong/dim. Recreated locally since the original is private to quiz_screen.dart.
class _BeastOptionTile extends StatelessWidget {
  final String label;
  final String text;
  final _BeastOptState state;
  final VoidCallback onTap;
  const _BeastOptionTile({required this.label, required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (Color border, Color bg, IconData? icon) = switch (state) {
      _BeastOptState.correct => (BrandColors.correct, BrandColors.correct.withValues(alpha: 0.16), Icons.check_circle),
      _BeastOptState.wrong => (BrandColors.wrong, BrandColors.wrong.withValues(alpha: 0.16), Icons.cancel),
      _BeastOptState.dim => (Colors.white24, Colors.transparent, null),
      _BeastOptState.idle => (Colors.white24, const Color(0xFF1A2133), null),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: state == _BeastOptState.idle || state == _BeastOptState.dim ? 1 : 2),
          borderRadius: BorderRadius.circular(Corners.md),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Corners.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: border.withValues(alpha: 0.22),
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        color: state == _BeastOptState.dim ? Colors.white38 : Colors.white)),
              ),
              if (icon != null) Icon(icon, color: border),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BeastResultsSheet extends StatelessWidget {
  final double score;
  final int correct;
  final int wrong;
  final int bestStreakRun;
  final int xpEarned;
  final bool knockedOut;
  final bool isNewBest;
  final VoidCallback onPlayAgain;
  final VoidCallback onDone;
  const _BeastResultsSheet({
    required this.score,
    required this.correct,
    required this.wrong,
    required this.bestStreakRun,
    required this.xpEarned,
    required this.knockedOut,
    required this.isNewBest,
    required this.onPlayAgain,
    required this.onDone,
  });

  String _headline(BuildContext context) {
    if (knockedOut) return context.tr('नॉक आउट! फिर भी शानदार कोशिश 🥊', 'Knocked out! Still a great run 🥊');
    if (score >= 30) return context.tr('असली बीस्ट परफॉर्मेंस! 🦁', 'That was a real beast run! 🦁');
    if (score >= 15) return context.tr('बढ़िया रफ़्तार! 🔥', 'Great pace! 🔥');
    return context.tr('अच्छी शुरुआत — फिर से कोशिश करें 💪', 'Good start — go again 💪');
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final p = context.scope.progress;
    final tier = p.beastTier;
    final next = tier.nextScore;
    final into = next == null ? 1.0 : ((p.beastBestScore - tier.minScore) / (next - tier.minScore)).clamp(0.0, 1.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_headline(context), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: Spacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(gradient: BrandColors.heroGradient, borderRadius: BorderRadius.circular(Corners.lg)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(score.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(context.tr('अंक', 'points'), style: const TextStyle(color: Colors.white70)),
                ),
              ]),
              if (isNewBest)
                Text(context.tr('नया रिकॉर्ड! 🏆', 'New best! 🏆'),
                    style: const TextStyle(color: BrandColors.sunrise, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
                _pill(context.tr('सही $correct', 'Correct $correct'), Icons.check_circle, BrandColors.correct),
                _pill(context.tr('गलत $wrong', 'Wrong $wrong'), Icons.cancel, BrandColors.wrong),
                _pill(context.tr('स्ट्रीक $bestStreakRun', 'Streak $bestStreakRun'), Icons.local_fire_department, BrandColors.saffron),
                _pill('+$xpEarned XP', Icons.bolt, BrandColors.sunrise),
              ]),
            ]),
          ),
          const SizedBox(height: Spacing.lg),
          Row(children: [
            Icon(Icons.military_tech, color: BrandColors.saffron, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${context.tr('टियर', 'Tier')}: ${tier.of(lang)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            if (next != null)
              Text(context.tr('अगला ${next.toStringAsFixed(0)}', 'Next ${next.toStringAsFixed(0)}'),
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
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
                minHeight: 8,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                color: BrandColors.saffron,
              ),
            ),
          ),
          const SizedBox(height: Spacing.xl),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share),
                label: Text(context.tr('शेयर करें', 'Share')),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  final hi = 'मैंने RailPariksha बीस्ट मोड में ${score.toStringAsFixed(1)} अंक बनाए! ⚡ (स्ट्रीक $bestStreakRun) '
                      'टियर: ${tier.hi}\n\nक्या आप मुझे हरा सकते हैं?';
                  final en = 'I scored ${score.toStringAsFixed(1)} in RailPariksha Beast Mode! ⚡ (streak $bestStreakRun) '
                      'Tier: ${tier.en}\n\nCan you beat me?';
                  SharePlus.instance.share(ShareParams(text: lang == 'en' ? en : hi));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.replay),
                label: Text(context.tr('फिर से खेलें', 'Play again')),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onPlayAgain();
                },
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onDone();
              },
              child: Text(context.tr('पूर्ण', 'Done')),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pill(String t, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      );
}
