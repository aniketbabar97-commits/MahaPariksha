import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads.dart';
import '../core/analytics.dart';
import '../core/app_scope.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../data/models.dart';
import '../data/pyq_repo.dart';
import '../logic/quiz_builder.dart';
import '../widgets/common.dart';
import 'pyq_screen.dart';
import 'quiz_screen.dart';

/// Questions in the student's language first; a single-language paper in the other language
/// is used only when nothing else is available.
List<Question> pyqInLang(List<Question> qs, String lang) {
  final mine = qs.where((q) => q.hasLang(lang)).toList();
  return mine.isEmpty ? qs : mine;
}

/// CBT pace for a test of [n] questions: 0.9 minutes each (100 in 90).
Duration pyqTestTime(int n) => Duration(minutes: max(1, (n * 0.9).round()));

/// A key that is different on every call, so an exam built fresh each time asks for its own ad
/// (a full paper is a 90-minute sitting; one ad per sitting).
String _freshKey(String what) => '$what:${DateTime.now().microsecondsSinceEpoch}';

// ---------------------------------------------------------------------------------------------
// By topic
// ---------------------------------------------------------------------------------------------

/// Topic-wise PYQs: the student's subjects, each with its topics and how many real previous-year
/// questions each one has.
class PyqTopicTab extends StatelessWidget {
  const PyqTopicTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final exam = s.builder.exam;
    if (exam == null) return const NoExamState();
    final mine = pyqSetPrefix[exam.id];
    return FutureBuilder<List<PyqTopic>>(
      future: pyqRepo.topics(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final byKey = {for (final t in snap.data!) '${t.subject}/${t.topic}': t};
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  context.tr('हर टॉपिक के असली पिछले वर्ष के प्रश्न: अभ्यास करें, फिर उस टॉपिक का टेस्ट दें और अपनी पकड़ परखें।',
                      'Real previous-year questions for every topic: practise, then take a timed topic test to prove you have it.'),
                ),
              ),
            ),
            for (final sid in exam.subjects)
              if (s.repo.subject(sid) != null) ..._subject(context, s.repo.subject(sid)!, byKey, mine),
            if (!s.progress.removedAds) const AdSlot(),
          ],
        );
      },
    );
  }

  List<Widget> _subject(BuildContext context, Subject sub, Map<String, PyqTopic> byKey, String? mine) {
    final lang = context.lang;
    final tiles = <Widget>[];
    for (final t in sub.topics) {
      final pt = byKey['${sub.id}/${t.id}'];
      if (pt == null) continue;
      final own = pt.countFor(mine);
      tiles.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ActionCard(
          icon: Icons.topic_outlined,
          color: BrandColors.sky,
          title: t.name.of(lang),
          subtitle: own > 0 && own != pt.count
              ? context.tr('${fmtCount(own)} आपकी परीक्षा से · कुल ${fmtCount(pt.count)} PYQ',
                  '${fmtCount(own)} from your exam · ${fmtCount(pt.count)} PYQs in all')
              : context.tr('${fmtCount(pt.count)} PYQ', '${fmtCount(pt.count)} PYQs'),
          onTap: () => push(context, (_) => PyqTopicScreen(topic: pt, topicName: t.name, subjectName: sub.name)),
        ),
      ));
    }
    if (tiles.isEmpty) return const [];
    // A native ad inside long subjects, so the ad sits where students scroll, not only at the foot.
    if (tiles.length > 6 && !AppScope.read(context).progress.removedAds) tiles.insert(4, const NativeAdTile());
    return [SectionTitle(sub.name.of(lang)), ...tiles];
  }
}

/// One topic: practise its previous-year questions, or take a timed topic test.
class PyqTopicScreen extends StatefulWidget {
  final PyqTopic topic;
  final Bi topicName;
  final Bi subjectName;
  const PyqTopicScreen({super.key, required this.topic, required this.topicName, required this.subjectName});

  @override
  State<PyqTopicScreen> createState() => _PyqTopicScreenState();
}

class _PyqTopicScreenState extends State<PyqTopicScreen> {
  static const _practiceSize = 20;
  static const _testSize = 25;
  late final Future<List<Question>> _qs = pyqRepo.topicQuestions(widget.topic);
  bool? _allExams; // null until decided from the counts

  @override
  void initState() {
    super.initState();
    Analytics.log('pyq_topic_open', {'subject': widget.topic.subject, 'topic': widget.topic.topic});
    if (!PyqAccess.unlocked(AppScope.read(context).progress)) RewardedAdManager.preload();
  }

  String? get _prefix => pyqSetPrefix[AppScope.read(context).builder.exam?.id];

  /// The pool for the current scope: the student's own exam's papers if there are enough of them,
  /// else every railway paper (the syllabus is the same).
  List<Question> _pool(List<Question> all) {
    final mine = _prefix;
    final own = mine == null ? all : all.where((q) => (q.pyq ?? '').startsWith(mine)).toList();
    final useAll = _allExams ?? own.length < _practiceSize;
    return pyqInLang(useAll ? all : own, context.lang);
  }

  /// Questions this student has not answered yet come first, so repeat practice stays fresh.
  List<Question> _pick(List<Question> pool, int n) {
    final stats = AppScope.read(context).progress.qStats;
    final fresh = pool.where((q) => !stats.containsKey(q.id)).toList()..shuffle(Random());
    final seen = pool.where((q) => stats.containsKey(q.id)).toList()..shuffle(Random());
    return [...fresh, ...seen].take(n).toList();
  }

  String get _title => widget.topicName.of(context.lang);

  void _practice(List<Question> pool) {
    final picked = _pick(pool, _practiceSize);
    withPyqAccess(
      context,
      () => startQuiz(
        context,
        QuizSpec(QuizMode.practice, picked, 'PYQ · ${widget.topicName.hi}', 'PYQ · ${widget.topicName.en}'),
      ),
    );
  }

  void _test(List<Question> pool) {
    final picked = _pick(pool, _testSize);
    final negative = AppScope.read(context).builder.exam?.negative ?? 1 / 3;
    withPyqAccess(
      context,
      () {
        Analytics.log('pyq_topic_test_start', {'topic': widget.topic.topic, 'n': picked.length});
        startQuiz(
          context,
          QuizSpec(QuizMode.pyqPaper, picked, 'टॉपिक टेस्ट · ${widget.topicName.hi}', 'Topic test · ${widget.topicName.en}',
              timeLimit: pyqTestTime(picked.length), negative: negative),
        );
      },
      paper: _freshKey('topic-test:${widget.topic.subject}/${widget.topic.topic}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: FutureBuilder<List<Question>>(
        future: _qs,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(context.tr('लोड नहीं हो सका', "Couldn't load these questions")));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          final mine = _prefix;
          final ownCount = mine == null ? all.length : all.where((q) => (q.pyq ?? '').startsWith(mine)).length;
          final pool = _pool(all);
          final testN = min(_testSize, pool.length);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.subjectName.of(lang), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(_title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(context.tr('${fmtCount(pool.length)} असली PYQ इस सेट में', '${fmtCount(pool.length)} real PYQs in this set')),
                  ]),
                ),
              ),
              if (mine != null && ownCount > 0 && ownCount < all.length) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  ChoiceChip(
                    label: Text(context.tr('मेरी परीक्षा ($ownCount)', 'My exam ($ownCount)')),
                    selected: !(_allExams ?? ownCount < _practiceSize),
                    onSelected: (_) => setState(() => _allExams = false),
                  ),
                  ChoiceChip(
                    label: Text(context.tr('सभी रेलवे परीक्षाएँ (${all.length})', 'All railway exams (${all.length})')),
                    selected: _allExams ?? ownCount < _practiceSize,
                    onSelected: (_) => setState(() => _allExams = true),
                  ),
                ]),
              ],
              const SizedBox(height: 12),
              ActionCard(
                icon: Icons.play_arrow_rounded,
                color: BrandColors.correct,
                title: context.tr('अभ्यास करें ($_practiceSize प्रश्न)', 'Practise ($_practiceSize questions)'),
                subtitle: context.tr('तुरंत उत्तर और व्याख्या · नए प्रश्न पहले', 'Instant answers and explanations · new questions first'),
                onTap: pool.isEmpty ? null : () => _practice(pool),
              ),
              const SizedBox(height: 10),
              ActionCard(
                icon: Icons.timer_outlined,
                color: BrandColors.wrong,
                title: context.tr('टॉपिक टेस्ट ($testN प्रश्न)', 'Topic test ($testN questions)'),
                subtitle: context.tr('${pyqTestTime(testN).inMinutes} मिनट · नेगेटिव मार्किंग · परीक्षा जैसा',
                    '${pyqTestTime(testN).inMinutes} min · negative marking · exam-hall style'),
                onTap: pool.isEmpty ? null : () => _test(pool),
              ),
              if (!AppScope.read(context).progress.removedAds) const AdSlot(),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Full exams
// ---------------------------------------------------------------------------------------------

/// The final full exam and one timed test per subject, all drawn from previous-year questions in
/// the real exam's pattern (question count, time, subject split, negative marking).
class PyqExamTab extends StatelessWidget {
  const PyqExamTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final exam = s.builder.exam;
    if (exam == null) return const NoExamState();
    final lang = context.lang;
    final total = exam.paperQuestions ?? 100;
    final minutes = exam.paperMinutes ?? 90;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              context.tr('असली परीक्षा के पैटर्न पर, पिछले वर्षों के असली प्रश्नों से बने टेस्ट। हर बार नए प्रश्न।',
                  'Tests built from real previous-year questions in the real exam pattern. Fresh questions every time.'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.workspace_premium,
          color: BrandColors.saffron,
          title: context.tr('फाइनल फुल एग्ज़ाम', 'Final full exam'),
          subtitle: context.tr('$total प्रश्न · $minutes मिनट · नेगेटिव मार्किंग · ${exam.name.hi}',
              '$total questions · $minutes min · negative marking · ${exam.name.en}'),
          onTap: () => _start(context, exam, exam.subjects, total, Duration(minutes: minutes), full: true),
        ),
        if (!s.progress.removedAds) const AdSlot(),
        SectionTitle(context.tr('विषयवार टेस्ट', 'Subject tests')),
        for (final sid in exam.subjects)
          if (s.repo.subject(sid) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ActionCard(
                icon: Icons.quiz_outlined,
                color: BrandColors.sky,
                title: s.repo.subject(sid)!.name.of(lang),
                subtitle: context.tr('25 प्रश्न · ${pyqTestTime(25).inMinutes} मिनट · केवल इसी विषय के PYQ',
                    '25 questions · ${pyqTestTime(25).inMinutes} min · PYQs from this subject only'),
                onTap: () => _start(context, exam, [sid], 25, pyqTestTime(25), name: s.repo.subject(sid)!.name),
              ),
            ),
        if (!s.progress.removedAds) const AdSlot(),
      ],
    );
  }

  Future<void> _start(BuildContext context, Exam exam, List<String> subjects, int total, Duration time,
      {bool full = false, Bi? name}) async {
    HapticFeedback.selectionClick();
    final s = AppScope.read(context);
    final lang = s.progress.lang;
    final key = _freshKey(full ? 'full-exam:${exam.id}' : 'subject-test:${subjects.first}');
    await withPyqAccess(context, () async {
      final nav = Navigator.of(context, rootNavigator: true);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      QuizSpec? spec;
      try {
        spec = await _build(context, exam, subjects, total, time, full: full, name: name, lang: lang);
      } catch (_) {
        spec = null;
      }
      nav.pop(); // the progress dialog
      if (!context.mounted) return;
      if (spec == null || spec.questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('इस परीक्षा के लिए अभी पर्याप्त प्रश्न नहीं हैं।', 'Not enough questions for this exam yet.'))));
        return;
      }
      Analytics.log(full ? 'pyq_full_exam_start' : 'pyq_subject_test_start', {'exam': exam.id, 'n': spec.questions.length});
      startQuiz(context, spec);
    }, paper: key);
  }

  /// Draws the exam: how many per subject follows the real paper's split, capped by what the
  /// student's exam family actually has; the year files are sampled a few at a time.
  static Future<QuizSpec?> _build(BuildContext context, Exam exam, List<String> subjects, int total, Duration time,
      {required bool full, Bi? name, required String lang}) async {
    final sets = (await pyqRepo.sets()).where((x) => x.railway).toList();
    final prefix = pyqSetPrefix[exam.id];
    final family = prefix == null ? <PyqSet>[] : sets.where((x) => x.exam.startsWith(prefix)).toList();
    int capacityOf(List<PyqSet> from, String subject) => from.fold(0, (a, x) => a + (x.subjects[subject] ?? 0));
    // Use the exam's own papers if they can fill every section, else all railway papers.
    final enough = family.isNotEmpty && subjects.every((sub) => capacityOf(family, sub) >= 60);
    final candidates = enough ? family : sets;
    final weights = {for (final sub in subjects) sub: full ? (exam.weights[sub] ?? 1) : 1};
    final capacity = {for (final sub in subjects) sub: capacityOf(candidates, sub)};
    final alloc = QuizBuilder.weightedAllocate(weights, capacity, total);
    final drawn = await pyqRepo.sampleBySubject(candidates, alloc, accept: (q) => q.hasLang(lang));
    final chosen = <Question>[for (final sub in subjects) ...?drawn[sub]];
    if (chosen.isEmpty) return null;
    return QuizSpec(
      QuizMode.pyqPaper,
      chosen,
      full ? 'PYQ फाइनल एग्ज़ाम' : 'PYQ विषय टेस्ट · ${name?.hi ?? ''}',
      full ? 'PYQ Final Exam' : 'PYQ subject test · ${name?.en ?? ''}',
      timeLimit: full ? time : pyqTestTime(chosen.length),
      negative: exam.negative,
    );
  }
}
