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

    test('mistake book quiz contains only mistakes', () {
      final q = repo.questionsFor(repo.exam('police_bharti')!).first;
      p.recordAnswer(q.id, false);
      expect(b.mistakes().questions.map((q) => q.id), [q.id]);
    });

    test('due flashcards respect the schedule', () {
      final all = b.dueCards(limit: 9999);
      p.cards[all.first.id] = CardState(due: today() + 3);
      expect(b.dueCards(limit: 9999).length, all.length - 1);
    });
  });
}
