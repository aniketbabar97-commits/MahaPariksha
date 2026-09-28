import 'dart:math';

import '../data/content_repo.dart';
import '../data/models.dart';
import '../data/progress.dart';

enum QuizMode { practice, daily, mock, speed, mistakes, bookmarks }

class QuizSpec {
  final QuizMode mode;
  final List<Question> questions;
  final String titleHi;
  final String titleEn;
  final Duration? timeLimit;
  final double negative;
  const QuizSpec(this.mode, this.questions, this.titleHi, this.titleEn,
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

/// A subject the user is falling behind on relative to the exam's own weighting.
class PacingGap {
  final String subject;

  /// How far actual practice share is below the exam's weighted share (0..1).
  final double deficit;

  /// Roughly how many of today's practice questions should go to this subject.
  final int recommendedDaily;
  const PacingGap(this.subject, this.deficit, this.recommendedDaily);
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
    return QuizSpec(QuizMode.practice, qs, t?.name.hi ?? s?.name.hi ?? 'अभ्यास',
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

  /// Which 1-2 subjects the user has under-practised relative to the exam's own
  /// question-count weighting — the same weights [_weightedAllocate] uses to build a
  /// mock test. Deliberately simple and time-invariant: a subject's fair share of total
  /// practice is `weight / totalWeight` regardless of how many days remain, so a gap here
  /// is just "practice share vs weighted share so far". Needs at least [minAttempts]
  /// answered questions in this exam before it says anything, so early users (where any
  /// split looks "off") aren't nagged.
  List<PacingGap> pacingGaps({int minAttempts = 15, double threshold = 0.08, int max = 2}) {
    final e = exam;
    if (e == null || e.subjects.isEmpty) return [];
    final totalWeight = e.subjects.fold(0, (a, s) => a + (e.weights[s] ?? 1));
    if (totalWeight <= 0) return [];
    final stats = subjectStats();
    final totalAnswered = e.subjects.fold(0, (a, s) => a + (stats[s]?[0] ?? 0));
    if (totalAnswered < minAttempts) return [];
    final gaps = <PacingGap>[];
    for (final s in e.subjects) {
      final expectedShare = (e.weights[s] ?? 1) / totalWeight;
      final actualShare = (stats[s]?[0] ?? 0) / totalAnswered;
      final deficit = expectedShare - actualShare;
      if (deficit > threshold) {
        final recommended = (expectedShare * progress.dailyGoal).round().clamp(1, progress.dailyGoal);
        gaps.add(PacingGap(s, deficit, recommended));
      }
    }
    gaps.sort((a, b) => b.deficit.compareTo(a.deficit));
    return gaps.take(max).toList();
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
    return QuizSpec(QuizMode.daily, chosen, 'आज का Daily 10', "Today's Daily 10");
  }

  /// Largest-remainder allocation of `total` items across `weights`, capped per key by
  /// `capacity`. Any amount a capped-out key can't absorb is re-run through the same
  /// proportional method across the remaining, not-yet-capped keys — so a thin subject
  /// (e.g. only 4 current-affairs questions in the bank) running out doesn't dump its
  /// shortfall as flat-random noise onto whichever subject happens to have leftover; the
  /// real subject weights keep governing where the rest goes.
  static Map<String, int> _weightedAllocate(Map<String, int> weights, Map<String, int> capacity, int total) {
    final result = <String, int>{for (final k in weights.keys) k: 0};
    var remainingKeys = weights.keys.where((k) => capacity[k]! > 0).toSet();
    var toPlace = total;
    while (toPlace > 0 && remainingKeys.isNotEmpty) {
      final totalWeight = remainingKeys.fold(0, (a, k) => a + weights[k]!);
      if (totalWeight == 0) break;
      final floor = <String, int>{};
      final frac = <String, double>{};
      var allocatedThisRound = 0;
      for (final k in remainingKeys) {
        final raw = toPlace * weights[k]! / totalWeight;
        floor[k] = raw.floor();
        frac[k] = raw - floor[k]!;
        allocatedThisRound += floor[k]!;
      }
      final byFrac = remainingKeys.toList()..sort((a, b) => frac[b]!.compareTo(frac[a]!));
      for (var i = 0; i < toPlace - allocatedThisRound && i < byFrac.length; i++) {
        floor[byFrac[i]] = floor[byFrac[i]]! + 1;
      }
      var overflow = 0;
      final exhausted = <String>[];
      for (final k in remainingKeys) {
        final room = capacity[k]! - result[k]!;
        final give = min(floor[k]!, room);
        result[k] = result[k]! + give;
        overflow += floor[k]! - give;
        if (give >= room) exhausted.add(k);
      }
      toPlace = overflow;
      if (exhausted.isEmpty) break; // nothing more can be placed without a capped key freeing up
      remainingKeys = remainingKeys.difference(exhausted.toSet());
    }
    return result;
  }

  /// Builds a mock test whose subject mix mirrors the real exam's question-count split
  /// (e.g. RPF's General-Awareness-heavy pattern, RRB JE's Maths/Science-heavy one) rather
  /// than splitting evenly across subjects.
  QuizSpec mock({int count = 25}) {
    final e = exam;
    final rnd = Random();
    final pool = _pool();
    final bySubject = <String, List<Question>>{};
    for (final q in pool) {
      bySubject.putIfAbsent(q.subject, () => []).add(q);
    }
    final chosen = <Question>[];
    if (bySubject.isNotEmpty) {
      final weights = {for (final s in bySubject.keys) s: e?.weights[s] ?? 1};
      final capacity = {for (final s in bySubject.keys) s: bySubject[s]!.length};
      final alloc = _weightedAllocate(weights, capacity, count);
      for (final s in bySubject.keys) {
        final list = bySubject[s]!..shuffle(rnd);
        chosen.addAll(list.take(alloc[s]!));
      }
      chosen.shuffle(rnd);
    }
    final negative = e?.negative ?? 0.0;
    return QuizSpec(QuizMode.mock, chosen, 'मॉक टेस्ट', 'Mock Test',
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
    return QuizSpec(QuizMode.mistakes, qs.take(15).toList(), 'गलतियों की कॉपी', 'Mistake Book');
  }

  QuizSpec bookmarked() {
    final qs = progress.bookmarks.map(repo.question).whereType<Question>().toList()..shuffle();
    return QuizSpec(QuizMode.bookmarks, qs.take(20).toList(), 'सहेजे गए प्रश्न', 'Saved Questions');
  }

  /// Reviews that are due, then up to the daily allowance of new cards.
  List<Flashcard> dueCards({String? subject, int limit = 20}) {
    final e = exam;
    final t = today();
    Iterable<Flashcard> cs = e == null ? repo.flashcards : repo.flashcardsFor(e);
    if (subject != null) cs = cs.where((c) => c.subject == subject);
    final reviews = <Flashcard>[];
    final fresh = <Flashcard>[];
    for (final c in cs) {
      final st = progress.cards[c.id];
      if (st == null) {
        fresh.add(c);
      } else if (st.due <= t) {
        reviews.add(c);
      }
    }
    final allowance = (Progress.newCardsPerDay - progress.newCardsSeenToday).clamp(0, Progress.newCardsPerDay);
    return [...reviews, ...fresh.take(allowance)].take(limit).toList();
  }

  Motivation? todaysMotivation() {
    if (repo.motivation.isEmpty) return null;
    return repo.motivation[today() % repo.motivation.length];
  }
}
