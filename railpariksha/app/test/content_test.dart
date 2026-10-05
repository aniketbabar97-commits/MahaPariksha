import 'dart:convert';

import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/logic/quiz_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepo repo;

  setUpAll(() async {
    repo = ContentRepo();
    await repo.load();
  });

  test('bundle loads with exams, questions, flashcards and motivation', () {
    expect(repo.exams, isNotEmpty);
    expect(repo.questions.length, greaterThan(50));
    expect(repo.flashcards, isNotEmpty);
    expect(repo.motivation, isNotEmpty);
  });

  test('every question references a known subject and topic and has a valid key', () {
    for (final q in repo.questions) {
      expect(repo.topic(q.subject, q.topic), isNotNull, reason: q.id);
      expect(q.answer, inInclusiveRange(0, 3), reason: q.id);
      expect(q.optionsHi.length, 4, reason: q.id);
      expect(q.optionsEn.length, 4, reason: q.id);
    }
  });

  test('every exam has practice content', () {
    for (final e in repo.exams) {
      expect(repo.questionsFor(e), isNotEmpty, reason: e.id);
      expect(repo.subjectsFor(e), isNotEmpty, reason: e.id);
    }
  });

  group('quiz builder', () {
    late Progress p;
    late QuizBuilder b;
    setUp(() {
      p = Progress()..examId = 'rrb_group_d';
      b = QuizBuilder(repo, p);
    });

    test('daily 10 has 10 distinct questions from the exam and is stable within a day', () {
      final a = b.daily();
      expect(a.questions.length, 10);
      expect(a.questions.map((q) => q.id).toSet().length, 10);
      final subjects = repo.exam('rrb_group_d')!.subjects.toSet();
      expect(a.questions.every((q) => subjects.contains(q.subject)), isTrue);
      expect(b.daily().questions.map((q) => q.id), a.questions.map((q) => q.id));
    });

    test('practice prefers unseen questions and excludes reported ones', () {
      final first = b.practice(subject: 'maths');
      for (final q in first.questions) {
        p.recordAnswer(q.id, true);
      }
      p.report(repo.questions.firstWhere((q) => q.subject == 'maths').id);
      final second = b.practice(subject: 'maths');
      final seen = first.questions.map((q) => q.id).toSet();
      expect(second.questions.where((q) => seen.contains(q.id)), isEmpty);
      expect(second.questions.any((q) => p.reported.contains(q.id)), isFalse);
    });

    test('mock mixes subjects, is timed and uses the exam negative marking', () {
      p.examId = 'rrb_ntpc';
      final m = b.mock();
      expect(m.questions.length, 25);
      expect(m.questions.map((q) => q.subject).toSet().length, greaterThan(2));
      expect(m.timeLimit, isNotNull);
      expect(m.negative, repo.exam('rrb_ntpc')!.negative);
      expect(m.instantFeedback, isFalse);
    });

    test('mock reflects the real exam subject weightage, not an even split', () {
      // RPF's real CBT is General-Awareness-heavy (maths/reasoning 35 each, GA subjects
      // 50 of 120) -- a mock of it should lean the same way, not split evenly across
      // its 5 subjects (which an even split would put at 20% each / 5 questions of 25).
      p.examId = 'rpf_constable';
      final m = b.mock(count: 60);
      final bySubject = <String, int>{};
      for (final q in m.questions) {
        bySubject[q.subject] = (bySubject[q.subject] ?? 0) + 1;
      }
      final gaCount = (bySubject['gk'] ?? 0) + (bySubject['current_affairs'] ?? 0) + (bySubject['railway_gk'] ?? 0);
      final mathsCount = bySubject['maths'] ?? 0;
      // Real weights: GA subjects sum to 50/120, maths alone is 35/120 -- GA should clearly
      // outweigh a single subject like maths, and far exceed an even 60/5=12-per-subject split.
      expect(gaCount, greaterThan(mathsCount));
      expect(gaCount, greaterThan(15));
    });

    test('every exam\'s mock allocation tracks its declared subject weights', () {
      // Broader than the RPF-specific check above: for every exam, a mock whose size
      // is small relative to the question pool should give the subject with the
      // highest declared weight at least as many questions as one with a much
      // lower weight (never the reverse), so weighting isn't silently ignored for
      // exams other than the one spot-checked above.
      for (final e in repo.exams) {
        p.examId = e.id;
        final weights = e.weights;
        if (weights.length < 2) continue;
        final sorted = weights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final top = sorted.first;
        final bottom = sorted.last;
        if (top.value == bottom.value) continue;
        final m = b.mock(count: 30);
        final bySubject = <String, int>{};
        for (final q in m.questions) {
          bySubject[q.subject] = (bySubject[q.subject] ?? 0) + 1;
        }
        expect(bySubject[top.key] ?? 0, greaterThanOrEqualTo(bySubject[bottom.key] ?? 0),
            reason: '${e.id}: top-weight subject ${top.key} (${top.value}) should not trail '
                'lowest-weight subject ${bottom.key} (${bottom.value})');
      }
    });

    test('mistake book quiz contains only mistakes', () {
      final q = repo.questionsFor(repo.exam('rrb_group_d')!).first;
      p.recordAnswer(q.id, false);
      expect(b.mistakes().questions.map((q) => q.id), [q.id]);
    });

    test('weak spots drill pulls only from topics below the weak-accuracy bar', () {
      // Pick one real topic from each subject (one with >= 4 questions so the
      // >=3-attempts-per-topic bar can actually be reached) and make it clearly
      // weak (wrong answers) or clearly strong (right answers).
      final byTopic = <String, List<String>>{};
      for (final q in repo.questionsFor(repo.exam('rrb_group_d')!)) {
        byTopic.putIfAbsent('${q.subject}/${q.topic}', () => []).add(q.id);
      }
      final weakKey = byTopic.entries.firstWhere((e) => e.key.startsWith('maths/') && e.value.length >= 4).key;
      final strongKey = byTopic.entries.firstWhere((e) => e.key.startsWith('reasoning/') && e.value.length >= 4).key;
      for (final id in byTopic[weakKey]!.take(4)) {
        p.recordAnswer(id, false);
      }
      for (final id in byTopic[strongKey]!.take(4)) {
        p.recordAnswer(id, true);
      }
      final drill = b.weakSpots();
      expect(drill.questions, isNotEmpty);
      expect(drill.questions.every((q) => '${q.subject}/${q.topic}' == weakKey), isTrue);
    });

    test('weak spots drill is empty with no answered history yet', () {
      expect(b.weakSpots().questions, isEmpty);
    });

    test('due flashcards: reviews first, new cards capped per day, future cards excluded', () {
      final first = b.dueCards(limit: 9999);
      expect(first.length, Progress.newCardsPerDay);
      p.cards[first[0].id] = CardState(due: today() + 3, firstSeen: today() - 5);
      p.cards[first[1].id] = CardState(due: today() - 1, firstSeen: today() - 5);
      final next = b.dueCards(limit: 9999);
      expect(next.first.id, first[1].id);
      expect(next.any((c) => c.id == first[0].id), isFalse);
    });

    test('current affairs: grouped by date (most recent first), quiz capped at 10 and scoped to that date', () {
      final byDate = b.currentAffairsByDate();
      expect(byDate, isNotEmpty);
      final dates = byDate.keys.toList();
      final sortedDesc = [...dates]..sort((a, c) => c.compareTo(a));
      expect(dates, sortedDesc);
      final latest = dates.first;
      final quiz = b.currentAffairsQuiz(latest);
      expect(quiz.questions, isNotEmpty);
      expect(quiz.questions.length, lessThanOrEqualTo(10));
      expect(quiz.questions.every((q) => q.date == latest), isTrue);
      // Hand-curated current-affairs questions have no date and are excluded.
      expect(byDate.values.expand((qs) => qs).every((q) => q.date != null), isTrue);
    });
  });

  group('content pack selection', () {
    test('peeks the version without decoding the whole pack', () {
      expect(ContentRepo.peekVersion('{"version":202610030716,"taxonomy":{}}'), 202610030716);
      expect(ContentRepo.peekVersion('  { "version" : 7 , "x": 1}'), 7);
      expect(ContentRepo.peekVersion('{"taxonomy":{},"version":7}'), isNull);
    });

    test('a newer cached pack wins, a stale or corrupt one falls back to the bundle', () {
      const bundled = '{"version":5,"which":"bundled"}';
      expect(ContentRepo.decodeNewestPack(bundled, null)['which'], 'bundled');
      expect(ContentRepo.decodeNewestPack(bundled, '{"version":9,"which":"cached"}')['which'], 'cached');
      expect(ContentRepo.decodeNewestPack(bundled, '{"version":3,"which":"cached"}')['which'], 'bundled');
      expect(ContentRepo.decodeNewestPack(bundled, '{"version":9,"which":')['which'], 'bundled');
      // Version not first in the cached pack: still decoded and compared properly.
      expect(ContentRepo.decodeNewestPack(bundled, '{"which":"cached","version":9}')['which'], 'cached');
    });
  });
  group('current-affairs feed', () {
    Map<String, dynamic> item(String id, String date) => {
          'id': id,
          's': 'current_affairs',
          't': 'national',
          'd': 1,
          'date': date,
          'q_hi': 'प्रश्न',
          'q_en': 'Question',
          'o_hi': ['क', 'ख', 'ग', 'घ'],
          'o_en': ['A', 'B', 'C', 'D'],
          'a': 2,
          'e_hi': 'व्याख्या',
          'e_en': 'Why',
        };
    String feed(int version, List<Map<String, dynamic>> qs) => jsonEncode({'version': version, 'questions': qs});

    test('merges new questions, skips known ids, older feeds and garbage', () {
      final r = ContentRepo();
      // Run on a loaded repo so subject/topic indexes exist.
      return r.load().then((_) {
        final before = r.questions.length;
        expect(r.mergeFeed(feed(5, [item('feedtest-1', '2099-01-02'), item('feedtest-2', '2099-01-02')])), 2);
        expect(r.questions.length, before + 2);
        expect(r.question('feedtest-1'), isNotNull);
        // The same ids again, and an older version, add nothing.
        expect(r.mergeFeed(feed(6, [item('feedtest-1', '2099-01-02')])), 0);
        expect(r.mergeFeed(feed(4, [item('feedtest-9', '2099-01-02')])), 0);
        expect(r.question('feedtest-9'), isNull);
        // Not JSON / wrong shape: no throw, nothing added.
        expect(r.mergeFeed('<html>404</html>'), 0);
        expect(r.mergeFeed('[]'), 0);
        expect(r.questions.length, before + 2);
        // A newer feed with one fresh id adds exactly that one.
        expect(r.mergeFeed(feed(7, [item('feedtest-1', '2099-01-02'), item('feedtest-3', '2099-01-03')])), 1);
      });
    });

    test('merged questions show up in the Current Affairs digest, newest day first', () async {
      final r = ContentRepo();
      await r.load();
      r.mergeFeed(feed(1, [item('feedtest-a', '2099-05-01')]));
      final byDate = QuizBuilder(r, Progress()).currentAffairsByDate();
      expect(byDate.keys.first, '2099-05-01');
      expect(byDate['2099-05-01']!.single.id, 'feedtest-a');
    });
  });
}
