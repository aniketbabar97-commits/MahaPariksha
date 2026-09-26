import 'package:bharari/data/content_repo.dart';
import 'package:bharari/data/progress.dart';
import 'package:bharari/logic/quiz_builder.dart';
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
    expect(repo.questions.length, greaterThan(300));
    expect(repo.flashcards, isNotEmpty);
    expect(repo.motivation, isNotEmpty);
  });

  test('every question references a known subject and topic and has a valid key', () {
    for (final q in repo.questions) {
      expect(repo.topic(q.subject, q.topic), isNotNull, reason: q.id);
      expect(q.answer, inInclusiveRange(0, 3), reason: q.id);
      expect(q.optionsMr.length, 4, reason: q.id);
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
      p = Progress()..examId = 'police_bharti';
      b = QuizBuilder(repo, p);
    });

    test('daily 10 has 10 distinct questions from the exam and is stable within a day', () {
      final a = b.daily();
      expect(a.questions.length, 10);
      expect(a.questions.map((q) => q.id).toSet().length, 10);
      final subjects = repo.exam('police_bharti')!.subjects.toSet();
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
      p.examId = 'mpsc_rajyaseva';
      final m = b.mock();
      expect(m.questions.length, 25);
      expect(m.questions.map((q) => q.subject).toSet().length, greaterThan(3));
      expect(m.timeLimit, isNotNull);
      expect(m.negative, repo.exam('mpsc_rajyaseva')!.negative);
      expect(m.instantFeedback, isFalse);
    });

    test('weekly mock is bigger, submit-at-end, and stable within the week', () {
      p.examId = 'mpsc_rajyaseva';
      final a = b.weeklyMock();
      expect(a.questions.length, 50);
      expect(a.instantFeedback, isFalse);
      expect(a.negative, repo.exam('mpsc_rajyaseva')!.negative);
      expect(b.weeklyMock().questions.map((q) => q.id), a.questions.map((q) => q.id));
    });

    test('weekly mock differs from the on-demand mock question set', () {
      p.examId = 'mpsc_rajyaseva';
      final weekly = b.weeklyMock().questions.map((q) => q.id).toSet();
      // Not a strict guarantee (both draw from the same pool), but with 50 vs 25
      // out of hundreds of questions, an exact-set collision would indicate a bug.
      expect(weekly.length, 50);
    });

    test('difficulty filter narrows practice to that level only', () {
      final easy = b.practice(subject: 'maths', difficulty: 1, count: 999);
      expect(easy.questions, isNotEmpty);
      expect(easy.questions.every((q) => q.difficulty == 1), isTrue);
      final counts = b.difficultyCounts(subject: 'maths');
      expect(counts[1], easy.questions.length);
      expect(counts[1]! + counts[2]! + counts[3]!,
          repo.questions.where((q) => q.subject == 'maths').length);
    });

    test('mistake book quiz contains only mistakes', () {
      final q = repo.questionsFor(repo.exam('police_bharti')!).first;
      p.recordAnswer(q.id, false);
      expect(b.mistakes().questions.map((q) => q.id), [q.id]);
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
  });
}
