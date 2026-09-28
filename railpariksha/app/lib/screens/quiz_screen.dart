import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../logic/quiz_builder.dart';
import '../widgets/celebrate.dart';
import 'results_screen.dart';

const kSupportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'support@railpariksha.app');

void startQuiz(BuildContext context, QuizSpec spec) {
  if (spec.questions.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('इस विभाग में अभी प्रश्न नहीं हैं। जल्द आ रहे हैं!', 'No questions here yet. Coming soon!'))));
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(spec: spec)));
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

  QuizSpec get spec => widget.spec;
  Question get q => spec.questions[index];
  bool get answered => answers[index] != null;

  @override
  void initState() {
    super.initState();
    qLang = AppScope.read(context).progress.lang;
    remaining = spec.timeLimit?.inSeconds ?? 0;
    if (spec.timeLimit != null) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => remaining--);
        if (remaining <= 0) _finish();
      });
    }
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
    if (!spec.instantFeedback) return; // mock: record at submit
    HapticFeedback.lightImpact();
    if (!correct) HapticFeedback.vibrate();
    final r = AppScope.read(context).progress.recordAnswer(q.id, correct);
    xpEarned += r.xp;
    if (spec.mode == QuizMode.speed) {
      if (correct) speedCorrect++;
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      if (index + 1 < spec.questions.length) {
        setState(() => index++);
      } else {
        _finish();
      }
      return;
    }
    if (mounted) await celebrate(context, r);
  }

  void _next() {
    if (index + 1 < spec.questions.length) {
      setState(() => index++);
    } else {
      _finish();
    }
  }

  bool _finished = false;
  void _finish() {
    if (_finished) return;
    _finished = true;
    timer?.cancel();
    final p = AppScope.read(context).progress;
    if (spec.mode == QuizMode.mock) {
      for (var i = 0; i < spec.questions.length; i++) {
        final a = answers[i];
        if (a != null) xpEarned += p.recordAnswer(spec.questions[i].id, a == spec.questions[i].answer).xp;
      }
    }
    if (spec.mode == QuizMode.speed) p.recordSpeed(speedCorrect);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          spec: spec,
          answers: answers,
          xpEarned: xpEarned,
          elapsed: DateTime.now().difference(started),
          speedScore: speedCorrect,
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    if (answers.every((a) => a == null)) return true;
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
    return r ?? false;
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
              tooltip: 'हिंदी / English',
              icon: Text(qLang == 'en' ? 'हिं' : 'EN', style: const TextStyle(fontWeight: FontWeight.w900)),
              onPressed: () => setState(() => qLang = qLang == 'en' ? 'hi' : 'en'),
            ),
            IconButton(
              icon: Icon(p.bookmarks.contains(q.id) ? Icons.bookmark : Icons.bookmark_border),
              onPressed: () => p.toggleBookmark(q.id),
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
            child: ListView(
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
                    : Row(children: [
                        if (index > 0)
                          Expanded(
                            child: OutlinedButton(onPressed: () => setState(() => index--), child: Text(context.tr('← वापस', '← Back'))),
                          ),
                        if (index > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: index + 1 < total ? () => setState(() => index++) : _confirmSubmit,
                            child: Text(index + 1 < total ? context.tr('आगे →', 'Next →') : context.tr('सबमिट करें', 'Submit')),
                          ),
                        ),
                      ]),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    final unanswered = answers.where((a) => a == null).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('टेस्ट सबमिट करना है?', 'Submit test?')),
        content: Text(unanswered > 0
            ? ctx.tr('$unanswered प्रश्न अभी हल करना बाकी हैं।', '$unanswered questions unanswered.')
            : ctx.tr('सभी प्रश्न हल हो गए हैं। शाबाश!', 'All questions answered. Well done!')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('रुकें', 'Wait'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('सबमिट', 'Submit'))),
        ],
      ),
    );
    if (ok == true) _finish();
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
          for (final r in reasons) ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
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
