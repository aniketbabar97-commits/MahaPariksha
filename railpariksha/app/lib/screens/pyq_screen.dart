import 'dart:math';

import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../data/pyq_repo.dart';
import '../logic/quiz_builder.dart';
import '../widgets/common.dart';
import 'quiz_screen.dart';
import '../core/format.dart';

/// App-wide PYQ pack loader (index + per-set files, cached in memory).
PyqRepo pyqRepo = PyqRepo();

/// The PYQ section is ad-supported: one rewarded ad unlocks it for [window].
/// Ad-free purchasers always have access.
class PyqAccess {
  static const window = Duration(minutes: 30);
  static DateTime? _until;

  static bool unlocked(Progress p) => p.removedAds || remaining() > Duration.zero;

  static Duration remaining() {
    final u = _until;
    if (u == null) return Duration.zero;
    final left = u.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  static void grant() => _until = DateTime.now().add(window);

  @visibleForTesting
  static void reset() => _until = null;
}

/// Runs [start] if the PYQ section is unlocked; otherwise offers a rewarded ad
/// that unlocks it, then runs [start].
Future<void> withPyqAccess(BuildContext context, VoidCallback start) async {
  final p = AppScope.read(context).progress;
  if (PyqAccess.unlocked(p)) return start();
  RewardedAdManager.preload();
  final watch = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_open, size: 36),
      title: Text(ctx.tr('PYQ अनलॉक करें', 'Unlock PYQs')),
      content: Text(ctx.tr(
          'एक छोटा विज्ञापन देखें और अगले ${PyqAccess.window.inMinutes} मिनट तक सभी पिछले वर्ष के प्रश्नपत्र हल करें।',
          'Watch one short ad to unlock every previous-year paper for the next ${PyqAccess.window.inMinutes} minutes.')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('बाद में', 'Later'))),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.play_circle_outline),
          label: Text(ctx.tr('विज्ञापन देखें', 'Watch ad')),
        ),
      ],
    ),
  );
  if (watch != true || !context.mounted) return;
  final shown = RewardedAdManager.showIfReady(onReward: () {
    PyqAccess.grant();
    if (context.mounted) start();
  });
  if (!shown && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('विज्ञापन लोड हो रहा है, कुछ सेकंड में फिर कोशिश करें। (इंटरनेट चालू रखें)',
            'The ad is still loading. Try again in a few seconds (needs internet).'))));
  }
}

/// Negative marking per wrong answer, as a fraction of one question's marks:
/// RRB/RPF CBTs deduct 1/3; SSC Tier-I deducts 0.5 of 2 marks.
double _negativeFor(PyqSet set) => set.railway ? 1 / 3 : 0.25;

class PyqScreen extends StatefulWidget {
  const PyqScreen({super.key});

  @override
  State<PyqScreen> createState() => _PyqScreenState();
}

class _PyqScreenState extends State<PyqScreen> {
  late final Future<List<PyqSet>> _sets = pyqRepo.sets();

  @override
  void initState() {
    super.initState();
    // Warm up the unlock ad -- unless this user never sees ads.
    if (!PyqAccess.unlocked(AppScope.read(context).progress)) RewardedAdManager.preload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final exam = s.builder.exam;
    final subjects = exam?.subjects.toSet();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('पिछले वर्ष के प्रश्न 📜', 'Previous year papers 📜'))),
      body: FutureBuilder<List<PyqSet>>(
        future: _sets,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          // Only sets that have questions in the student's exam syllabus.
          int relevant(PyqSet set) => subjects == null
              ? set.count
              : set.subjects.entries.where((e) => subjects.contains(e.key)).fold(0, (a, e) => a + e.value);
          final sets = snap.data!.where((x) => relevant(x) > 0).toList();
          if (sets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.tr('जल्द आ रहे हैं!', 'Coming soon!'), style: Theme.of(context).textTheme.titleMedium),
              ),
            );
          }
          final rail = sets.where((x) => x.railway).toList();
          final other = sets.where((x) => !x.railway).toList();
          final total = sets.fold<int>(0, (a, x) => a + relevant(x));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _AccessBanner(total: total),
              if (rail.isNotEmpty) ...[
                SectionTitle(context.tr('रेलवे प्रश्नपत्र 🚆', 'Railway papers 🚆')),
                for (final x in rail) _SetTile(set: x, relevant: relevant(x)),
              ],
              if (other.isNotEmpty) ...[
                SectionTitle(context.tr('समान पाठ्यक्रम वाली परीक्षाएँ (SSC) 📘', 'Same-syllabus exams (SSC) 📘')),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    context.tr(
                        'ये रेलवे के प्रश्नपत्र नहीं हैं: SSC परीक्षाओं के असली प्रश्न, उसी गणित, रीज़निंग और सामान्य ज्ञान पाठ्यक्रम पर।',
                        'Not railway papers: real SSC exam questions on the same maths, reasoning and GK syllabus.'),
                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                  ),
                ),
                for (final x in other) _SetTile(set: x, relevant: relevant(x)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AccessBanner extends StatelessWidget {
  final int total;
  const _AccessBanner({required this.total});

  @override
  Widget build(BuildContext context) {
    final p = context.scope.progress;
    final left = PyqAccess.remaining();
    final status = p.removedAds
        ? context.tr('विज्ञापन-मुक्त: हमेशा अनलॉक ✅', 'Ad-free: always unlocked ✅')
        : left > Duration.zero
            ? context.tr('अनलॉक: ${left.inMinutes + 1} मिनट बाकी 🔓', 'Unlocked: ${left.inMinutes + 1} min left 🔓')
            : context.tr('एक छोटा विज्ञापन देखकर ${PyqAccess.window.inMinutes} मिनट के लिए अनलॉक करें 🔒',
                'Watch one short ad to unlock for ${PyqAccess.window.inMinutes} min 🔒');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('${fmtCount(total)} असली परीक्षा प्रश्न', '${fmtCount(total)} real exam questions'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(status),
          const SizedBox(height: 4),
          Text(
            context.tr('RRB/RPF के आधिकारिक प्रश्नपत्रों व उत्तर कुंजी से। जहाँ उपलब्ध हो, आपकी भाषा में।',
                'From official RRB/RPF question papers and answer keys. In your language where available.'),
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5),
          ),
        ]),
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  final PyqSet set;
  final int relevant;
  const _SetTile({required this.set, required this.relevant});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ActionCard(
          icon: set.railway ? Icons.train : Icons.menu_book,
          color: set.railway ? BrandColors.saffron : BrandColors.skyLight,
          title: set.title,
          subtitle: context.tr('${fmtCount(relevant)} प्रश्न · ${set.papers.length} प्रश्नपत्र',
              '${fmtCount(relevant)} questions · ${set.papers.length} papers'),
          onTap: () => push(context, (_) => PyqSetScreen(set: set)),
        ),
      );
}

class PyqSetScreen extends StatefulWidget {
  final PyqSet set;
  const PyqSetScreen({super.key, required this.set});

  @override
  State<PyqSetScreen> createState() => _PyqSetScreenState();
}

class _PyqSetScreenState extends State<PyqSetScreen> {
  late final Future<List<Question>> _qs = pyqRepo.questions(widget.set);
  static const _practiceSize = 20;

  /// Questions in the student's language first; a single-language paper in the
  /// other language is used only when nothing else is available.
  List<Question> _inLang(List<Question> qs) {
    final lang = context.lang;
    final mine = qs.where((q) => q.hasLang(lang)).toList();
    return mine.isEmpty ? qs : mine;
  }

  void _practice(List<Question> pool, String? subject) {
    final picked = [..._inLang(subject == null ? pool : pool.where((q) => q.subject == subject).toList())]
      ..shuffle(Random());
    final title = widget.set.title;
    withPyqAccess(
      context,
      () => startQuiz(context, QuizSpec(QuizMode.practice, picked.take(_practiceSize).toList(), 'PYQ · $title', 'PYQ · $title')),
    );
  }

  void _paper(List<Question> all, PyqPaper paper) {
    final qs = _inLang(all.where((q) => q.pyq == paper.label).toList());
    // CBT pace: RRB papers allow 0.9 min per question (100 in 90 min).
    final minutes = max(1, (qs.length * 0.9).round());
    withPyqAccess(
      context,
      () => startQuiz(
        context,
        QuizSpec(QuizMode.pyqPaper, qs, paper.label, paper.label,
            timeLimit: Duration(minutes: minutes), negative: _negativeFor(widget.set)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final examSubjects = s.builder.exam?.subjects.toSet();
    return Scaffold(
      appBar: AppBar(title: Text(widget.set.title)),
      body: FutureBuilder<List<Question>>(
        future: _qs,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(context.tr('लोड नहीं हो सका', "Couldn't load these questions")));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          final pool = examSubjects == null ? all : all.where((q) => examSubjects.contains(q.subject)).toList();
          final bySubject = <String, int>{};
          for (final q in pool) {
            bySubject[q.subject] = (bySubject[q.subject] ?? 0) + 1;
          }
          final lang = context.lang;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              ActionCard(
                icon: Icons.shuffle,
                color: BrandColors.correct,
                title: context.tr('मिश्रित अभ्यास ($_practiceSize प्रश्न)', 'Mixed practice ($_practiceSize questions)'),
                subtitle: context.tr('${fmtCount(pool.length)} प्रश्नों में से · तुरंत उत्तर और व्याख्या',
                    'From ${fmtCount(pool.length)} questions · instant answers & explanations'),
                onTap: pool.isEmpty ? null : () => _practice(pool, null),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in bySubject.entries)
                  ActionChip(
                    avatar: const Icon(Icons.play_arrow, size: 18),
                    label: Text('${s.repo.subject(e.key)?.name.of(lang) ?? e.key} (${e.value})'),
                    onPressed: () => _practice(pool, e.key),
                  ),
              ]),
              SectionTitle(context.tr('पूरे प्रश्नपत्र हल करें 📝', 'Attempt a full paper 📝')),
              for (final paper in widget.set.papers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ActionCard(
                    icon: Icons.description,
                    color: BrandColors.sky,
                    title: paper.shortLabel.isEmpty ? widget.set.title : paper.shortLabel,
                    subtitle: context.tr(
                        '${paper.count} प्रश्न · ${max(1, (paper.count * 0.9).round())} मिनट · असली परीक्षा जैसा',
                        '${paper.count} questions · ${max(1, (paper.count * 0.9).round())} min · exam-hall style'),
                    onTap: () => _paper(all, paper),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
