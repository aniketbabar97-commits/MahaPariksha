import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads.dart';
import '../core/analytics.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../data/pyq_repo.dart';
import '../logic/quiz_builder.dart';
import '../widgets/common.dart';
import 'pyq_modes.dart';
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

  /// A full paper is a 90-minute sitting, so it is unlocked per paper (one ad each) rather than by
  /// the 30-minute window that covers practice sets. [paperWindow] leaves room to finish it and
  /// to come back to the same paper without paying twice.
  static const paperWindow = Duration(hours: 2);
  static final Map<String, DateTime> _papers = {};

  static bool paperUnlocked(Progress p, String label) {
    if (p.removedAds) return true;
    final until = _papers[label];
    return until != null && until.isAfter(DateTime.now());
  }

  static void grantPaper(String label, {Duration? window}) => _papers[label] = DateTime.now().add(window ?? paperWindow);

  /// When no ad can be loaded (no fill, no network) a student must not be locked out of the
  /// papers they came for -- and nobody earns anything from an ad that can't load. So a failed
  /// load opens the section for [courtesyWindow], at most [courtesyLimit] times per app session.
  static const courtesyWindow = Duration(minutes: 20);
  static const courtesyLimit = 2;
  static int _courtesyUsed = 0;

  /// [paper] is the label of the full paper being opened, if that is what the student asked for.
  static bool grantCourtesy({String? paper}) {
    if (_courtesyUsed >= courtesyLimit) return false;
    _courtesyUsed++;
    if (paper != null) {
      grantPaper(paper, window: courtesyWindow);
    } else {
      _until = DateTime.now().add(courtesyWindow);
    }
    return true;
  }

  @visibleForTesting
  static void reset() {
    _until = null;
    _papers.clear();
    _courtesyUsed = 0;
  }
}

/// Runs [start] if the PYQ section is unlocked; otherwise offers a rewarded ad that unlocks it,
/// then runs [start]. Pass [paper] (the paper's label) for a full paper: those are unlocked one
/// by one, while practice sets share a 30-minute window.
Future<void> withPyqAccess(BuildContext context, VoidCallback start, {String? paper}) async {
  final p = AppScope.read(context).progress;
  final open = paper == null ? PyqAccess.unlocked(p) : PyqAccess.paperUnlocked(p, paper);
  if (open) return start();
  RewardedAdManager.preload();
  Analytics.log('pyq_gate_shown', {'kind': paper == null ? 'practice' : 'paper'});
  final watch = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_open, size: 36),
      title: Text(paper == null ? ctx.tr('PYQ अनलॉक करें', 'Unlock PYQs') : ctx.tr('यह प्रश्नपत्र अनलॉक करें', 'Unlock this paper')),
      content: Text(paper == null
          ? ctx.tr('एक छोटा विज्ञापन देखें और अगले ${PyqAccess.window.inMinutes} मिनट तक सभी अभ्यास सेट हल करें।',
              'Watch one short ad to unlock all practice sets for the next ${PyqAccess.window.inMinutes} minutes.')
          : ctx.tr('एक छोटा विज्ञापन देखें और यह पूरा प्रश्नपत्र ${PyqAccess.paperWindow.inHours} घंटे तक खोलें।',
              'Watch one short ad to open this full paper for ${PyqAccess.paperWindow.inHours} hours.')),
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
    if (paper == null) {
      PyqAccess.grant();
    } else {
      PyqAccess.grantPaper(paper);
    }
    Analytics.log('pyq_unlocked', {'kind': paper == null ? 'practice' : 'paper', 'via': 'ad'});
    if (context.mounted) start();
  });
  if (!shown && context.mounted && RewardedAdManager.unavailable && PyqAccess.grantCourtesy(paper: paper)) {
    Analytics.log('pyq_unlocked', {'kind': paper == null ? 'practice' : 'paper', 'via': 'courtesy'});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('अभी कोई विज्ञापन उपलब्ध नहीं — ${PyqAccess.courtesyWindow.inMinutes} मिनट के लिए PYQ खुले हैं।',
            'No ad is available right now — PYQs are open for ${PyqAccess.courtesyWindow.inMinutes} minutes on us.'))));
    start();
    return;
  }
  if (!shown && context.mounted) {
    Analytics.log('pyq_ad_not_ready');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('विज्ञापन लोड हो रहा है, कुछ सेकंड में फिर कोशिश करें। (इंटरनेट चालू रखें)',
            'The ad is still loading. Try again in a few seconds (needs internet).'))));
  }
}

/// Negative marking per wrong answer, as a fraction of one question's marks:
/// RRB/RPF CBTs deduct 1/3; SSC Tier-I deducts 0.5 of 2 marks.
double _negativeFor(PyqSet set) => set.railway ? 1 / 3 : 0.25;

/// Exam id -> how that exam's PYQ sets are named in the pack (RRB JE branches share "RRB JE").
const pyqSetPrefix = {
  'rrb_ntpc': 'RRB NTPC',
  'rrb_group_d': 'RRB Group D',
  'rrb_alp': 'RRB ALP',
  'rrb_technician': 'RRB Technician',
  'rrb_je': 'RRB JE',
  'rrb_je_mechanical': 'RRB JE',
  'rrb_je_civil': 'RRB JE',
  'rrb_je_electrical': 'RRB JE',
  'rpf_constable': 'RPF Constable',
  'rpf_si': 'RPF SI',
};

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
    Analytics.log('pyq_open', {'from_exam': AppScope.read(context).progress.examId ?? ''});
    // Warm up the unlock ad -- unless this user never sees ads.
    if (!PyqAccess.unlocked(AppScope.read(context).progress)) RewardedAdManager.preload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final exam = s.builder.exam;
    final subjects = exam?.subjects.toSet();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('पिछले वर्ष के प्रश्न 📜', 'Previous year papers 📜')),
        bottom: TabBar(tabs: [
          Tab(text: context.tr('वर्षवार', 'By year')),
          Tab(text: context.tr('टॉपिकवार', 'By topic')),
          Tab(text: context.tr('फुल एग्ज़ाम', 'Full exams')),
        ]),
      ),
      body: TabBarView(children: [
      FutureBuilder<List<PyqSet>>(
        future: _sets,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          // Only sets that have questions in the student's exam syllabus.
          int relevant(PyqSet set) => subjects == null
              ? set.count
              : set.subjects.entries.where((e) => subjects.contains(e.key)).fold(0, (a, e) => a + e.value);
          // The student's own exam first (stable: the rest keep their order).
          final mine = pyqSetPrefix[s.builder.exam?.id];
          final all = snap.data!.where((x) => relevant(x) > 0).toList();
          final sets = mine == null
              ? all
              : [...all.where((x) => x.exam.startsWith(mine)), ...all.where((x) => !x.exam.startsWith(mine))];
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
                for (var i = 0; i < rail.length; i++) ...[
                  _SetTile(set: rail[i], relevant: relevant(rail[i])),
                  if (!s.progress.removedAds && i % 8 == 7 && i < rail.length - 1) const NativeAdTile(),
                ],
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
              if (!s.progress.removedAds) const Center(child: AdBanner()),
            ],
          );
        },
      ),
      const PyqTopicTab(),
      const PyqExamTab(),
      ]),
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
    // Only say something when there is good news; how the unlock works is explained at the moment it
    // matters (the unlock dialog), not on every visit.
    final status = p.removedAds
        ? context.tr('विज्ञापन-मुक्त ✅', 'Ad-free ✅')
        : left > Duration.zero
            ? context.tr('अनलॉक: ${left.inMinutes + 1} मिनट बाकी 🔓', 'Unlocked: ${left.inMinutes + 1} min left 🔓')
            : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('${fmtCount(total)} असली परीक्षा प्रश्न', '${fmtCount(total)} real exam questions'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (status != null) ...[const SizedBox(height: 4), Text(status)],
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
              '${fmtCount(relevant)} questions · ${set.papers.length} ${set.papers.length == 1 ? 'paper' : 'papers'}'),
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
  late Future<List<Question>> _qs = pyqRepo.questions(widget.set);
  static const _practiceSize = 20;

  @override
  void initState() {
    super.initState();
    Analytics.log('pyq_set_open', {'set': widget.set.title});
  }

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
      () {
        Analytics.log('pyq_paper_start', {'paper': paper.label, 'n': qs.length});
        startQuiz(
          context,
          QuizSpec(QuizMode.pyqPaper, qs, paper.label, paper.label,
              timeLimit: Duration(minutes: minutes), negative: _negativeFor(widget.set)),
        );
      },
      paper: paper.label,
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
            return PyqLoadError(onRetry: () => setState(() => _qs = pyqRepo.questions(widget.set)));
          }
          if (!snap.hasData) return PyqLoading(file: widget.set.file, kb: widget.set.kb);
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
              for (var i = 0; i < widget.set.papers.length; i++) ...[
                if (!s.progress.removedAds && i == 6) const NativeAdTile(),
                _paperTile(all, widget.set.papers[i]),
              ],
              if (!s.progress.removedAds) const Center(child: AdBanner()),
            ],
          );
        },
      ),
    );
  }

  Widget _paperTile(List<Question> all, PyqPaper paper) {
    return Builder(builder: (context) {
      return Padding(
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
      );
    });
  }
}

/// Loading state for a set or topic shard. Bundled files open instantly; a file that is not in the
/// APK downloads once, and the student is told so (with its size) instead of staring at a spinner.
class PyqLoading extends StatelessWidget {
  final String file;
  final int kb;
  const PyqLoading({super.key, required this.file, required this.kb});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
        valueListenable: pyqRepo.downloading,
        builder: (context, current, _) {
          final mb = (kb / 1024).toStringAsFixed(kb >= 1024 ? 0 : 1);
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              if (current == file) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    context.tr('पहली बार डाउनलोड हो रहा है (~$mb MB) — फिर ऑफ़लाइन भी चलेगा',
                        'Downloading once (~$mb MB) — works offline after this'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              ],
            ]),
          );
        },
      );
}

/// Could not load a set or shard: almost always "not bundled and no internet right now".
class PyqLoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const PyqLoadError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off, size: 40, color: Theme.of(context).hintColor),
            const SizedBox(height: 12),
            Text(
              context.tr('यह पेपर एक बार इंटरनेट से डाउनलोड होता है। इंटरनेट चालू करके फिर कोशिश करें।',
                  'This paper downloads once over the internet. Turn on data or Wi-Fi and try again.'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                onRetry();
              },
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('फिर कोशिश करें', 'Try again')),
            ),
          ]),
        ),
      );
}
