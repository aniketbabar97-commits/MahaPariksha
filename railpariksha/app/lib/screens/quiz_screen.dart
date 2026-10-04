import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/ads.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../logic/quiz_builder.dart';
import '../widgets/celebrate.dart';
import '../widgets/common.dart';
import 'results_screen.dart';

const kSupportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'support@railpariksha.app');

void startQuiz(BuildContext context, QuizSpec spec) {
  if (spec.questions.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('इस विभाग में अभी प्रश्न नहीं हैं। जल्द आ रहे हैं!', 'No questions here yet. Coming soon!'))));
    return;
  }
  push(context, (_) => QuizScreen(spec: spec));
}

const _labelsHi = ['अ', 'ब', 'क', 'ड'];
const _labelsEn = ['A', 'B', 'C', 'D'];

class QuizScreen extends StatefulWidget {
  final QuizSpec spec;
  const QuizScreen({super.key, required this.spec});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int index = 0;
  late final List<int?> answers = List.filled(widget.spec.questions.length, null);
  late String qLang;
  Timer? timer;
  late int remaining;
  int speedCorrect = 0;
  int xpEarned = 0;
  final started = DateTime.now();
  // Speed Round already earns real per-question Rewards via recordAnswer
  // (same as Practice), but _select returns early for it before the
  // immediate celebrate() call below -- popping a dialog mid-sprint would
  // eat into the 60-second timer. Collected here and celebrated once in
  // _finish() instead, same pattern as the mock-mode batch below.
  Reward? _notable;

  // Test-mode (mock/placement) state mirroring the real RRB CBT interface:
  // the palette's "not visited" vs "not answered" distinction needs to know
  // which questions were ever opened, and Mark for Review is independent of
  // whether an answer is chosen (answered+marked still gets evaluated).
  final Set<int> _visited = {0};
  final Set<int> _marked = {};
  late final List<int> _timeMs = List.filled(widget.spec.questions.length, 0);
  final Stopwatch _qWatch = Stopwatch()..start();

  QuizSpec get spec => widget.spec;
  Question get q => spec.questions[index];
  bool get answered => answers[index] != null;

  @override
  void initState() {
    super.initState();
    final p = AppScope.read(context).progress;
    qLang = p.lang;
    if (spec.mode == QuizMode.mock && !p.removedAds) InterstitialAdManager.preload();
    remaining = spec.timeLimit?.inSeconds ?? 0;
    _startTimer();
  }

  void _startTimer() {
    _qWatch.start();
    if (spec.timeLimit == null) return;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => remaining--);
      if (remaining <= 0) _finish();
    });
  }

  /// Stops the countdown while a confirmation dialog is open, so [_finish]
  /// (which does a Navigator.pushReplacement) can never fire while that
  /// dialog's route is on top of QuizScreen's -- it would replace the dialog
  /// instead of the quiz, leaving the quiz route stuck underneath Results.
  void _pauseTimer() {
    timer?.cancel();
    timer = null;
    _qWatch.stop();
  }

  void _bankTime() {
    _timeMs[index] += _qWatch.elapsedMilliseconds;
    _qWatch.reset();
  }

  void _goTo(int i) {
    if (i == index || i < 0 || i >= spec.questions.length) return;
    _bankTime();
    setState(() {
      index = i;
      _visited.add(i);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _select(int i) async {
    if (spec.instantFeedback && answered) return;
    final correct = i == q.answer;
    setState(() => answers[index] = i);
    if (!spec.instantFeedback) {
      // Mock mode defers correctness feedback to submit time, but the tap
      // itself still deserves the same tactile acknowledgement every other
      // option tap in the app gives -- instead of silence until Next/Submit.
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.lightImpact();
    if (!correct) HapticFeedback.vibrate();
    final r = AppScope.read(context).progress.recordAnswer(q.id, correct);
    xpEarned += r.xp;
    if (spec.mode == QuizMode.speed) {
      if (r.levelUp || r.streakMilestone != null || r.goalCompleted || r.freezeSaved) _notable = r;
      if (correct) speedCorrect++;
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      if (index + 1 < spec.questions.length) {
        _goTo(index + 1);
      } else {
        _finish();
      }
      return;
    }
    if (mounted) await celebrate(context, r);
  }

  void _next() {
    if (index + 1 < spec.questions.length) {
      _goTo(index + 1);
    } else {
      _finish();
    }
  }

  bool _finished = false;
  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    timer?.cancel();
    _bankTime();
    _qWatch.stop();
    final p = AppScope.read(context).progress;
    // Only one of these per-question Rewards can ever carry a notable event
    // (level/streak/goal are once-a-day state crossings, not per-question),
    // so collecting the last non-trivial one and celebrating once after the
    // loop -- instead of per question, which batch-grading a mock test would
    // otherwise fire several dialogs back to back for.
    Reward? notable = _notable;
    if (spec.mode == QuizMode.mock) {
      for (var i = 0; i < spec.questions.length; i++) {
        final a = answers[i];
        if (a == null) continue;
        final r = p.recordAnswer(spec.questions[i].id, a == spec.questions[i].answer);
        xpEarned += r.xp;
        if (r.levelUp || r.streakMilestone != null || r.goalCompleted || r.freezeSaved) notable = r;
      }
    }
    if (spec.mode == QuizMode.speed) p.recordSpeed(speedCorrect);
    if (notable != null && mounted) await celebrate(context, notable);
    if (!mounted) return;
    pushReplacementReveal(
      context,
      (_) => ResultsScreen(
        spec: spec,
        answers: answers,
        xpEarned: xpEarned,
        elapsed: DateTime.now().difference(started),
        speedScore: speedCorrect,
        timePerQuestion: [for (final ms in _timeMs) Duration(milliseconds: ms)],
      ),
    );
  }

  Future<bool> _confirmExit() async {
    if (answers.every((a) => a == null)) return true;
    _pauseTimer();
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('अभ्यास रोकना है?', 'Stop practice?')),
        content: Text(ctx.tr('अब तक की प्रगति सहेज ली गई है।', 'Your progress so far is saved.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('जारी रखें', 'Continue'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('रोकें', 'Stop'))),
        ],
      ),
    );
    final exiting = r ?? false;
    if (!exiting && !_finished) _startTimer();
    return exiting;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.scope.progress;
    final total = spec.questions.length;
    final options = q.options(qLang);
    final labels = qLang == 'en' ? _labelsEn : _labelsHi;
    final showFeedback = spec.instantFeedback && answered && spec.mode != QuizMode.speed;
    final subject = context.scope.repo.subject(q.subject);
    final topic = context.scope.repo.topic(q.subject, q.topic);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(qLang == 'en' ? spec.titleEn : spec.titleHi, overflow: TextOverflow.ellipsis),
          actions: [
            if (spec.timeLimit != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Chip(
                  avatar: Icon(Icons.timer, size: 18, color: remaining < 15 ? BrandColors.wrong : null),
                  label: Text('${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: remaining < 15 ? BrandColors.wrong : null)),
                ),
              ),
            IconButton(
              tooltip: context.tr('भाषा बदलें', 'Switch language'),
              icon: Text(qLang == 'en' ? 'हिं' : 'EN', style: const TextStyle(fontWeight: FontWeight.w900)),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => qLang = qLang == 'en' ? 'hi' : 'en');
              },
            ),
            if (!spec.instantFeedback)
              IconButton(
                tooltip: context.tr('प्रश्न पैलेट', 'Question palette'),
                icon: const Icon(Icons.grid_view_rounded),
                onPressed: _showPalette,
              ),
            IconButton(
              tooltip: p.bookmarks.contains(q.id)
                  ? context.tr('सहेजा गया, हटाएं', 'Saved, remove')
                  : context.tr('प्रश्न सहेजें', 'Save question'),
              icon: Icon(p.bookmarks.contains(q.id) ? Icons.bookmark : Icons.bookmark_border),
              onPressed: () {
                HapticFeedback.selectionClick();
                p.toggleBookmark(q.id);
              },
            ),
          ],
        ),
        body: Column(children: [
          LinearProgressIndicator(
            value: spec.mode == QuizMode.speed ? remaining / 60 : (index + (answered ? 1 : 0)) / total,
            minHeight: 5,
            color: BrandColors.saffron,
            backgroundColor: BrandColors.saffron.withValues(alpha: 0.15),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: ListView(
                key: ValueKey(index),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  Row(children: [
                    Text(
                        spec.mode == QuizMode.speed
                            ? context.tr('सही: $speedCorrect', 'Correct: $speedCorrect')
                            : '${index + 1} / $total',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${subject?.name.of(qLang) ?? ''} · ${topic?.name.of(qLang) ?? ''}',
                          overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                    ),
                    if (_marked.contains(index))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.flag, size: 18, color: _PaletteState.marked.color),
                      ),
                    _DifficultyDots(q.difficulty),
                  ]),
                  const SizedBox(height: 14),
                  Text(q.text.of(qLang), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.45)),
                  const SizedBox(height: 18),
                  for (var i = 0; i < options.length; i++)
                    _OptionTile(
                      label: labels[i],
                      text: options[i],
                      state: _optionState(i),
                      onTap: () => _select(i),
                    ),
                  if (showFeedback) _Explanation(q: q, lang: qLang, correct: answers[index] == q.answer),
                ],
              ),
            ),
          ),
          if (spec.mode != QuizMode.speed)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: spec.instantFeedback
                    ? FilledButton(
                        onPressed: answered ? _next : null,
                        child: Text(index + 1 < total ? context.tr('अगला प्रश्न →', 'Next question →') : context.tr('परिणाम देखें 🏁', 'See results 🏁')),
                      )
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          Expanded(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                              onPressed: answered
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      setState(() => answers[index] = null);
                                    }
                                  : null,
                              icon: const Icon(Icons.backspace_outlined, size: 18),
                              label: Text(context.tr('उत्तर हटाएं', 'Clear response'), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                foregroundColor: _PaletteState.marked.color,
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() => _marked.contains(index) ? _marked.remove(index) : _marked.add(index));
                              },
                              icon: Icon(_marked.contains(index) ? Icons.flag : Icons.outlined_flag, size: 18),
                              label: Text(
                                  _marked.contains(index)
                                      ? context.tr('रिव्यू हटाएं', 'Unmark review')
                                      : context.tr('रिव्यू के लिए चिह्नित', 'Mark for review'),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ]),
                        Row(children: [
                          if (index > 0)
                            Expanded(
                              child: OutlinedButton(onPressed: () => _goTo(index - 1), child: Text(context.tr('← वापस', '← Back'))),
                            ),
                          if (index > 0) const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: index + 1 < total ? () => _goTo(index + 1) : _confirmSubmit,
                              child: Text(index + 1 < total ? context.tr('सेव करें और आगे →', 'Save & next →') : context.tr('सबमिट करें', 'Submit')),
                            ),
                          ),
                        ]),
                      ]),
              ),
            ),
        ]),
      ),
    );
  }

  _PaletteState _status(int i) {
    final a = answers[i] != null;
    final m = _marked.contains(i);
    if (a && m) return _PaletteState.answeredMarked;
    if (m) return _PaletteState.marked;
    if (a) return _PaletteState.answered;
    if (_visited.contains(i)) return _PaletteState.notAnswered;
    return _PaletteState.notVisited;
  }

  Map<_PaletteState, int> _statusCounts() {
    final counts = {for (final s in _PaletteState.values) s: 0};
    for (var i = 0; i < spec.questions.length; i++) {
      counts[_status(i)] = counts[_status(i)]! + 1;
    }
    return counts;
  }

  Widget _legend(BuildContext ctx, Map<_PaletteState, int> counts) => Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final s in _PaletteState.values)
            Row(mainAxisSize: MainAxisSize.min, children: [
              _PaletteDot(state: s, size: 22, child: Text('${counts[s]}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
              const SizedBox(width: 6),
              Text(s.label(ctx), style: const TextStyle(fontSize: 12.5)),
            ]),
        ],
      );

  Future<void> _showPalette() async {
    HapticFeedback.selectionClick();
    _pauseTimer();
    final target = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ctx.tr('प्रश्न पैलेट', 'Question palette'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _legend(ctx, _statusCounts()),
              const SizedBox(height: 14),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 52, mainAxisSpacing: 10, crossAxisSpacing: 10),
                  itemCount: spec.questions.length,
                  itemBuilder: (_, i) => Semantics(
                    button: true,
                    label: '${i + 1}, ${_status(i).label(ctx)}',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(ctx, i),
                      child: _PaletteDot(
                        state: _status(i),
                        size: 44,
                        current: i == index,
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _status(i) == _PaletteState.notVisited ? Theme.of(ctx).colorScheme.onSurface : Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'submit'),
                  child: Text(ctx.tr('टेस्ट सबमिट करें', 'Submit test')),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (!mounted || _finished) return;
    if (target == 'submit') {
      await _confirmSubmit();
      return;
    }
    _startTimer();
    if (target is int) _goTo(target);
  }

  Future<void> _confirmSubmit() async {
    final counts = _statusCounts();
    _pauseTimer();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('टेस्ट सबमिट करना है?', 'Submit test?')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _legend(ctx, counts),
          if (counts[_PaletteState.answeredMarked]! > 0) ...[
            const SizedBox(height: 12),
            Text(
                ctx.tr('रिव्यू के लिए चिह्नित जिन प्रश्नों का उत्तर दिया गया है, उनका मूल्यांकन होगा — असली परीक्षा की तरह।',
                    'Marked questions that have an answer will be evaluated — just like the real exam.'),
                style: TextStyle(fontSize: 12.5, color: Theme.of(ctx).hintColor)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('रुकें', 'Wait'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('सबमिट', 'Submit')),
          ),
        ],
      ),
    );
    if (ok == true) {
      _finish();
    } else if (!_finished) {
      _startTimer();
    }
  }

  _OptState _optionState(int i) {
    final a = answers[index];
    if (a == null) return _OptState.idle;
    if (!spec.instantFeedback) return a == i ? _OptState.selected : _OptState.idle;
    if (i == q.answer) return _OptState.correct;
    if (i == a) return _OptState.wrong;
    return _OptState.dim;
  }
}

enum _OptState { idle, selected, correct, wrong, dim }

/// The five question states of the RRB/TCS iON CBT palette, with the same
/// colour language students see on exam day.
enum _PaletteState {
  answered(BrandColors.correct),
  notAnswered(BrandColors.wrong),
  notVisited(Colors.transparent),
  marked(Color(0xFF6A3FB5)),
  answeredMarked(Color(0xFF6A3FB5));

  final Color color;
  const _PaletteState(this.color);

  String label(BuildContext context) => switch (this) {
        answered => context.tr('उत्तर दिया', 'Answered'),
        notAnswered => context.tr('उत्तर नहीं दिया', 'Not answered'),
        notVisited => context.tr('नहीं देखा', 'Not visited'),
        marked => context.tr('रिव्यू के लिए', 'Marked for review'),
        answeredMarked => context.tr('उत्तर + रिव्यू', 'Answered & marked'),
      };
}

class _PaletteDot extends StatelessWidget {
  final _PaletteState state;
  final double size;
  final bool current;
  final Widget child;
  const _PaletteDot({required this.state, required this.size, required this.child, this.current = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: state == _PaletteState.notVisited ? scheme.surfaceContainerHighest : state.color,
          shape: BoxShape.circle,
          border: current ? Border.all(color: BrandColors.saffron, width: 3) : null,
        ),
        child: child,
      ),
      if (state == _PaletteState.answeredMarked)
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.36,
            height: size * 0.36,
            decoration: BoxDecoration(
              color: BrandColors.correct,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 1.5),
            ),
            child: Icon(Icons.check, size: size * 0.24, color: Colors.white),
          ),
        ),
    ]);
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String text;
  final _OptState state;
  final VoidCallback onTap;
  const _OptionTile({required this.label, required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color border, Color bg, IconData? icon) = switch (state) {
      _OptState.correct => (BrandColors.correct, BrandColors.correct.withValues(alpha: 0.12), Icons.check_circle),
      _OptState.wrong => (BrandColors.wrong, BrandColors.wrong.withValues(alpha: 0.12), Icons.cancel),
      _OptState.selected => (BrandColors.saffron, BrandColors.saffron.withValues(alpha: 0.12), Icons.radio_button_checked),
      _OptState.dim => (scheme.outlineVariant, Colors.transparent, null),
      _OptState.idle => (scheme.outlineVariant, Theme.of(context).cardTheme.color ?? scheme.surface, null),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TapScale(
        scale: state == _OptState.idle ? 0.98 : 1.0,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: state == _OptState.idle || state == _OptState.dim ? 1 : 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: border.withValues(alpha: 0.18),
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        color: state == _OptState.dim ? Theme.of(context).hintColor : null)),
              ),
              if (icon != null) Icon(icon, color: border),
            ]),
          ),
        ),
        ),
      ),
    );
  }
}

class _DifficultyDots extends StatelessWidget {
  final int d;
  const _DifficultyDots(this.d);

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(
          3,
          (i) => Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < d ? BrandColors.saffron : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
        ),
      );
}

class _Explanation extends StatelessWidget {
  final Question q;
  final String lang;
  final bool correct;
  const _Explanation({required this.q, required this.lang, required this.correct});

  Widget _block(BuildContext context, IconData icon, Color color, String title, String body) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(fontSize: 15, height: 1.5)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final en = lang == 'en';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child)),
      child: Card(
        margin: const EdgeInsets.only(top: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              correct ? (en ? 'Correct! Brilliant 🎉' : 'सही! शानदार 🎉') : (en ? 'Not quite — learn why 💡' : 'गलत, पर सीखते हैं 💡'),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: correct ? BrandColors.correct : BrandColors.wrong),
            ),
            _block(context, Icons.lightbulb, BrandColors.skyLight, en ? 'Explanation' : 'स्पष्टीकरण', q.explanation.of(lang)),
            if (q.hook != null) _block(context, Icons.psychology_alt, BrandColors.saffron, en ? 'Memory trick' : 'याद रखने की तरकीब', q.hook!.of(lang)),
            if (q.fact != null) _block(context, Icons.star, BrandColors.correct, en ? 'Also remember' : 'यह भी याद रखें', q.fact!.of(lang)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(en ? 'Report an error' : 'गलती बताएं'),
                onPressed: () => _report(context),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _report(BuildContext context) async {
    final reasons = [
      context.tr('उत्तर गलत है', 'Answer is wrong'),
      context.tr('प्रश्न स्पष्ट नहीं है', 'Question is unclear'),
      context.tr('भाषा / टाइपिंग की गलती', 'Language / typo error'),
      context.tr('स्पष्टीकरण गलत है', 'Explanation is wrong'),
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(ctx.tr('क्या गलत है?', "What's wrong?"), style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final r in reasons)
            ListTile(
              title: Text(r),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(ctx, r);
              },
            ),
        ]),
      ),
    );
    if (reason == null || !context.mounted) return;
    context.scope.progress.report(q.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.tr('धन्यवाद! यह प्रश्न समीक्षा के लिए छिपा दिया गया है।', 'Thanks! This question is hidden for review.')),
      action: SnackBarAction(
        label: context.tr('ईमेल करें', 'Email us'),
        onPressed: () => launchUrl(Uri(
          scheme: 'mailto',
          path: kSupportEmail,
          query: 'subject=${Uri.encodeComponent('RailPariksha report ${q.id}')}&body=${Uri.encodeComponent('$reason\n\n${q.text.hi}')}',
        )),
      ),
    ));
  }
}
