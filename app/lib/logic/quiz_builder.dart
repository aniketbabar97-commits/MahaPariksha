import 'dart:math';

import '../data/content_repo.dart';
import '../data/models.dart';
import '../data/progress.dart';

enum QuizMode { practice, daily, mock, speed, mistakes, bookmarks }

class QuizSpec {
  final QuizMode mode;
  final List<Question> questions;
  final String titleMr;
  final String titleEn;
  final Duration? timeLimit;
  final double negative;
  const QuizSpec(this.mode, this.questions, this.titleMr, this.titleEn,
      {this.timeLimit, this.negative = 0});

  /// Instant feedback after each answer (practice-style) vs reveal at the end (test-style).
  bool get instantFeedback => mode != QuizMode.mock;
}

class TopicStat {
  final String subject;
  final String topic;
  final int attempts;
  final int correct;
  const TopicStat(this.subject, this.topic, this.attempts, this.correct);
  double get accuracy => attempts == 0 ? 0 : correct / attempts;
}

class QuizBuilder {
  final ContentRepo repo;
  final Progress progress;
  QuizBuilder(this.repo, this.progress);

  Exam? get exam => progress.examId == null ? null : repo.exam(progress.examId!);

  List<Question> _pool({String? subject, String? topic}) {
    final e = exam;
    Iterable<Question> qs = e == null ? repo.questions : repo.questionsFor(e);
    if (subject != null) qs = qs.where((q) => q.subject == subject);
    if (topic != null) qs = qs.where((q) => q.topic == topic);
    return qs.where((q) => !progress.reported.contains(q.id)).toList();
  }

  /// Unseen first, then previously wrong, then least practised.
  int _priority(Question q) {
    final s = progress.qStats[q.id];
    if (s == null) return 0;
    if (s[2] == 0) return 1;
    return 2 + s[0];
  }

  List<Question> _pick(List<Question> pool, int n, Random rnd) {
    pool.shuffle(rnd);
    pool.sort((a, b) => _priority(a).compareTo(_priority(b)));
    return pool.take(n).toList();
  }

  QuizSpec practice({required String subject, String? topic, int count = 10}) {
    final s = repo.subject(subject);
    final t = topic == null ? null : repo.topic(subject, topic);
    final qs = _pick(_pool(subject: subject, topic: topic), count, Random());
    return QuizSpec(QuizMode.practice, qs, t?.name.mr ?? s?.name.mr ?? 'सराव',
        t?.name.en ?? s?.name.en ?? 'Practice');
  }

  List<TopicStat> topicStats() {
    final agg = <String, List<int>>{};
    progress.qStats.forEach((id, s) {
      final q = repo.question(id);
      if (q == null) return;
      final a = agg.putIfAbsent('${q.subject}/${q.topic}', () => [0, 0]);
      a[0] += s[0];
      a[1] += s[1];
    });
    return agg.entries.map((e) {
      final p = e.key.split('/');
      return TopicStat(p[0], p[1], e.value[0], e.value[1]);
    }).toList();
  }

  Map<String, List<int>> subjectStats() {
    final agg = <String, List<int>>{};
    progress.qStats.forEach((id, s) {
      final q = repo.question(id);
      if (q == null) return;
      final a = agg.putIfAbsent(q.subject, () => [0, 0]);
      a[0] += s[0];
      a[1] += s[1];
    });
    return agg;
  }

  /// Same set all day (seeded by date + exam): 6 weak-topic, 4 mixed.
  QuizSpec daily() {
    final e = exam;
    final rnd = Random(today() * 31 + (e?.id.hashCode ?? 0));
    final pool = _pool();
    final weak = topicStats().where((t) => t.attempts >= 3 && t.accuracy < 0.7).map((t) => '${t.subject}/${t.topic}').toSet();
    final weakPool = pool.where((q) => weak.contains('${q.subject}/${q.topic}')).toList();
    final chosen = <Question>[..._pick(weakPool, 6, rnd)];
    final rest = pool.where((q) => !chosen.contains(q)).toList();
    chosen.addAll(_pick(rest, 10 - chosen.length, rnd));
    chosen.shuffle(rnd);
    return QuizSpec(QuizMode.daily, chosen, 'आजचे Daily 10', "Today's Daily 10");
  }

  QuizSpec mock({int count = 25}) {
    final e = exam;
    final rnd = Random();
    final pool = _pool();
    final bySubject = <String, List<Question>>{};
    for (final q in pool) {
      bySubject.putIfAbsent(q.subject, () => []).add(q);
    }
    final chosen = <Question>[];
    final subjects = bySubject.keys.toList()..shuffle(rnd);
    var i = 0;
    while (chosen.length < count && bySubject.values.any((l) => l.isNotEmpty)) {
      final list = bySubject[subjects[i % subjects.length]]!;
      if (list.isNotEmpty) chosen.add(list.removeAt(rnd.nextInt(list.length)));
      i++;
    }
    final negative = e?.negative ?? 0.0;
    return QuizSpec(QuizMode.mock, chosen, 'सराव परीक्षा (Mock)', 'Mock Test',
        timeLimit: Duration(seconds: 48 * chosen.length), negative: negative);
  }

  QuizSpec speed() {
    final pool = _pool().where((q) => q.difficulty == 1).toList();
    final qs = (pool.isEmpty ? _pool() : pool)..shuffle();
    return QuizSpec(QuizMode.speed, qs.take(40).toList(), 'स्पीड राउंड', 'Speed Round',
        timeLimit: const Duration(seconds: 60));
  }

  QuizSpec mistakes() {
    final qs = progress.mistakes.map(repo.question).whereType<Question>().toList()..shuffle();
    return QuizSpec(QuizMode.mistakes, qs.take(15).toList(), 'चुकांची वही', 'Mistake Book');
  }

  QuizSpec bookmarked() {
    final qs = progress.bookmarks.map(repo.question).whereType<Question>().toList()..shuffle();
    return QuizSpec(QuizMode.bookmarks, qs.take(20).toList(), 'जतन केलेले प्रश्न', 'Saved Questions');
  }

  List<Flashcard> dueCards({String? subject, int limit = 20}) {
    final e = exam;
    final t = today();
    Iterable<Flashcard> cs = e == null ? repo.flashcards : repo.flashcardsFor(e);
    if (subject != null) cs = cs.where((c) => c.subject == subject);
    final list = cs.where((c) {
      final st = progress.cards[c.id];
      return st == null || st.due <= t;
    }).toList();
    // Reviews already started come first, then new cards.
    list.sort((a, b) => (progress.cards.containsKey(a.id) ? 0 : 1).compareTo(progress.cards.containsKey(b.id) ? 0 : 1));
    return list.take(limit).toList();
  }

  Motivation? todaysMotivation() {
    if (repo.motivation.isEmpty) return null;
    return repo.motivation[today() % repo.motivation.length];
  }
}
