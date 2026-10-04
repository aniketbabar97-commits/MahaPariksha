import 'dart:math';

import '../data/content_repo.dart';
import '../data/models.dart';
import '../data/progress.dart';

enum QuizMode { practice, daily, mock, speed, mistakes, bookmarks, beast, currentAffairs, placement, weakSpots }

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
  bool get instantFeedback => mode != QuizMode.mock && mode != QuizMode.placement;
}

/// A learner's level in one subject/topic, from their answer history there.
/// [weights] is the easy/medium/hard (1/2/3) mix their practice sets draw.
enum Mastery {
  newcomer({1: 5, 2: 4, 3: 1}),
  building({1: 6, 2: 3, 3: 1}),
  steady({1: 2, 2: 5, 3: 3}),
  strong({1: 1, 2: 4, 3: 5});

  final Map<int, int> weights;
  const Mastery(this.weights);

  /// Fewer than this many answers is too little history to judge accuracy.
  static const minAttempts = 5;

  static Mastery of(int attempts, double accuracy) {
    if (attempts < minAttempts) return newcomer;
    if (accuracy < 0.5) return building;
    if (accuracy < 0.75) return steady;
    return strong;
  }
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

  /// This subject's share of the real exam's question-count weighting (0..1) --
  /// the same number [QuizBuilder.mock] uses to build its subject split, surfaced
  /// here so the UI can say *why* this subject deserves the catch-up, not just that
  /// it does.
  final double examShare;
  const PacingGap(this.subject, this.deficit, this.recommendedDaily, this.examShare);
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
    final qs = _pickAdaptive(_pool(subject: subject, topic: topic), count, Random(), mastery(subject, topic));
    return QuizSpec(QuizMode.practice, qs, t?.name.hi ?? s?.name.hi ?? 'अभ्यास',
        t?.name.en ?? s?.name.en ?? 'Practice');
  }

  /// [attempts, correct] answered so far in a subject, or one topic of it.
  List<int> _scopeStats(String subject, String? topic) {
    var attempts = 0, correct = 0;
    progress.qStats.forEach((id, s) {
      final q = repo.question(id);
      if (q == null || q.subject != subject || (topic != null && q.topic != topic)) return;
      attempts += s[0];
      correct += s[1];
    });
    return [attempts, correct];
  }

  /// The learner's current level in a subject/topic, driving how hard their
  /// practice sets are.
  Mastery mastery(String subject, [String? topic]) {
    final st = _scopeStats(subject, topic);
    return Mastery.of(st[0], st[0] == 0 ? 0 : st[1] / st[0]);
  }

  /// Like [_pick], but splits [count] across difficulty tiers according to
  /// [level] so sets get harder as accuracy rises, then orders easy→hard so
  /// each session warms up before the tough questions.
  List<Question> _pickAdaptive(List<Question> pool, int count, Random rnd, Mastery level) {
    final byTier = <String, List<Question>>{};
    for (final q in pool) {
      byTier.putIfAbsent('${q.difficulty.clamp(1, 3)}', () => []).add(q);
    }
    if (byTier.length < 2) return _pick(pool, count, rnd);
    final weights = {for (final k in byTier.keys) k: level.weights[int.parse(k)]!};
    final alloc = _weightedAllocate(weights, {for (final e in byTier.entries) e.key: e.value.length}, count);
    final chosen = <Question>[];
    for (final k in (byTier.keys.toList()..sort())) {
      chosen.addAll(_pick(byTier[k]!, alloc[k] ?? 0, rnd));
    }
    // Every tier had a non-zero weight, so the allocation can only fall short
    // of [count] when the whole pool is smaller; top up just in case.
    if (chosen.length < count) {
      final rest = pool.where((q) => !chosen.contains(q)).toList();
      chosen.addAll(_pick(rest, count - chosen.length, rnd));
    }
    return chosen;
  }

  /// How many questions a weak-topic are worth drawing from any single topic in
  /// [weakSpots], so one very-weak, well-stocked topic can't crowd out the rest --
  /// the drill should feel like a round of all the user's weak spots, not a retake
  /// of just the single worst one.
  static const _weakSpotsPerTopic = 3;

  /// Cross-subject drill built purely from the user's weak topics (same accuracy/
  /// attempts bar as the Daily 10's weak-topic slice, see [daily]), but not capped
  /// at 6 slots and not mixed with filler -- every question in here is from a topic
  /// the user is demonstrably struggling with, for a focused "grind my weak spots"
  /// session. Empty when there isn't enough answered history yet to call anything
  /// weak (same bar [daily] and [pacingGaps] use), so the UI can hide the entry
  /// point rather than open on nothing.
  QuizSpec weakSpots({int count = 15}) {
    final rnd = Random();
    final weak = topicStats().where((t) => t.attempts >= 3 && t.accuracy < 0.7).toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final chosen = <Question>[];
    final seen = <String>{};
    for (final t in weak) {
      if (chosen.length >= count) break;
      final topicPool = _pool(subject: t.subject, topic: t.topic).where((q) => !seen.contains(q.id)).toList();
      final take = min(_weakSpotsPerTopic, count - chosen.length);
      final picked = _pick(topicPool, take, rnd);
      seen.addAll(picked.map((q) => q.id));
      chosen.addAll(picked);
    }
    if (chosen.length < count && weak.isNotEmpty) {
      final topUpPool = weak
          .expand((t) => _pool(subject: t.subject, topic: t.topic))
          .where((q) => !seen.contains(q.id))
          .toList();
      chosen.addAll(_pick(topUpPool, count - chosen.length, rnd));
    }
    chosen.shuffle(rnd);
    return QuizSpec(QuizMode.weakSpots, chosen, 'कमज़ोर टॉपिक ड्रिल 🎯', 'Weak Spots Drill 🎯');
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
        gaps.add(PacingGap(s, deficit, recommended, expectedShare));
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

  /// Short, ungraded diagnostic for onboarding: a weighted mix across the chosen
  /// exam's subjects (round-robin by subject), never negatively marked, used only
  /// to suggest a starting daily goal.
  QuizSpec placement({int count = 10}) {
    final rnd = Random();
    final pool = _pool();
    final bySubject = <String, List<Question>>{};
    for (final q in pool) {
      bySubject.putIfAbsent(q.subject, () => []).add(q);
    }
    final chosen = <Question>[];
    final subjects = bySubject.keys.toList()..shuffle(rnd);
    var i = 0;
    while (chosen.length < count && subjects.isNotEmpty && bySubject.values.any((l) => l.isNotEmpty)) {
      final list = bySubject[subjects[i % subjects.length]]!;
      if (list.isNotEmpty) chosen.add(list.removeAt(rnd.nextInt(list.length)));
      i++;
    }
    chosen.shuffle(rnd);
    return QuizSpec(QuizMode.placement, chosen, 'स्तर जांच', 'Level Check', negative: 0);
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
  ///
  /// [full] builds a full-length paper matching the real exam's actual CBT-1 question
  /// count and time limit (e.g. RRB NTPC's 100 questions / 90 minutes) instead of the
  /// quick 25-question default -- falls back to the quick defaults if the exam has no
  /// paper length on file yet.
  QuizSpec mock({int count = 25, bool full = false}) {
    final e = exam;
    final rnd = Random();
    final pool = _pool();
    final bySubject = <String, List<Question>>{};
    for (final q in pool) {
      bySubject.putIfAbsent(q.subject, () => []).add(q);
    }
    final targetCount = full ? (e?.paperQuestions ?? count) : count;
    final chosen = <Question>[];
    if (bySubject.isNotEmpty) {
      final weights = {for (final s in bySubject.keys) s: e?.weights[s] ?? 1};
      final capacity = {for (final s in bySubject.keys) s: bySubject[s]!.length};
      final alloc = _weightedAllocate(weights, capacity, targetCount);
      // Section-wise like the real CBT paper: subjects in the exam's own
      // order, questions shuffled within each section.
      final order = [
        ...?e?.subjects.where(bySubject.containsKey),
        ...bySubject.keys.where((s) => !(e?.subjects.contains(s) ?? false)),
      ];
      for (final s in order) {
        final list = bySubject[s]!..shuffle(rnd);
        chosen.addAll(list.take(alloc[s]!));
      }
    }
    final negative = e?.negative ?? 0.0;
    final timeLimit = full && e?.paperMinutes != null
        ? Duration(minutes: e!.paperMinutes!)
        : Duration(seconds: 48 * chosen.length);
    return QuizSpec(
        QuizMode.mock,
        chosen,
        full ? 'फुल-लेंथ मॉक' : 'मॉक टेस्ट',
        full ? 'Full-Length Mock' : 'Mock Test',
        timeLimit: timeLimit,
        negative: negative);
  }

  /// Builds a Beast Mode sprint pool: enough questions (weighted the same way [mock]
  /// mirrors the real exam's subject split) to comfortably outlast [seconds] of rapid-fire
  /// answering, capped by pool size. The screen itself cycles/reshuffles this list if a very
  /// fast player exhausts it before the timer ends, so this only needs to be "plenty", not exact.
  QuizSpec beast({int seconds = 60}) {
    final e = exam;
    final rnd = Random();
    final pool = _pool();
    final bySubject = <String, List<Question>>{};
    for (final q in pool) {
      bySubject.putIfAbsent(q.subject, () => []).add(q);
    }
    // Rough budget assuming ~2.5s per question, generously capped.
    final count = (seconds / 2.5).ceil().clamp(15, 80);
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
    return QuizSpec(QuizMode.beast, chosen, 'बीस्ट मोड ⚡', 'Beast Mode ⚡',
        timeLimit: Duration(seconds: seconds), negative: negative);
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

  /// Auto-drafted current-affairs questions grouped by the ISO date they were drafted
  /// on, most recent date first. Hand-curated current-affairs questions carry no
  /// `date` and are excluded here -- they already surface through normal subject
  /// practice instead. Reported (hidden) questions are excluded, same as [_pool].
  Map<String, List<Question>> currentAffairsByDate() {
    final byDate = <String, List<Question>>{};
    for (final q in repo.questions) {
      if (q.date == null || progress.reported.contains(q.id)) continue;
      (byDate[q.date!] ??= []).add(q);
    }
    final keys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: byDate[k]!};
  }

  /// A short quiz (up to 10 Qs) built from one day's auto-drafted current-affairs
  /// questions, for the dated Current Affairs archive.
  QuizSpec currentAffairsQuiz(String date) {
    final qs = currentAffairsByDate()[date] ?? const <Question>[];
    return QuizSpec(QuizMode.currentAffairs, qs.take(10).toList(), 'करेंट अफेयर्स क्विज़', 'Current Affairs Quiz');
  }
}
