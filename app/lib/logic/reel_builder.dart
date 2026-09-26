import 'dart:math';

import '../data/content_repo.dart';
import '../data/models.dart';
import '../data/progress.dart';
import 'quiz_builder.dart';

enum ReelKind { question, flashcard, fact, motivation }

/// One card in the endless "Bharari Reel" — a single unit of bite-sized,
/// swipe-to-next content. Only one of the typed fields is set, matching [kind].
class ReelItem {
  final ReelKind kind;
  final Question? question;
  final Flashcard? flashcard;
  final Motivation? motivation;
  final Bi? fact;
  final Subject? factSubject;
  final Topic? factTopic;
  const ReelItem.question(this.question)
      : kind = ReelKind.question, flashcard = null, motivation = null, fact = null, factSubject = null, factTopic = null;
  const ReelItem.flashcard(this.flashcard)
      : kind = ReelKind.flashcard, question = null, motivation = null, fact = null, factSubject = null, factTopic = null;
  const ReelItem.motivation(this.motivation)
      : kind = ReelKind.motivation, question = null, flashcard = null, fact = null, factSubject = null, factTopic = null;
  const ReelItem.fact(this.fact, this.factSubject, this.factTopic)
      : kind = ReelKind.fact, question = null, flashcard = null, motivation = null;
}

/// Generates an endless, weighted-random mix of questions, flashcards, quick facts
/// and motivation — the vertical swipe feed. Not seeded by day: every open is fresh,
/// like a real feed, but questions still lean toward the user's weak topics.
class ReelBuilder {
  final ContentRepo repo;
  final Progress progress;
  final QuizBuilder quiz;
  final Random _rnd = Random();
  ReelBuilder(this.repo, this.progress, this.quiz);

  List<Question> _questionPool() {
    final e = quiz.exam;
    final all = e == null ? repo.questions : repo.questionsFor(e);
    return all.where((q) => !progress.reported.contains(q.id)).toList();
  }

  List<Flashcard> _cardPool() {
    final e = quiz.exam;
    return e == null ? repo.flashcards : repo.flashcardsFor(e);
  }

  List<TopicNote> _notePool() {
    final e = quiz.exam;
    if (e == null) return repo.subjects.expand((s) => s.topics.map((t) => repo.note(s.id, t.id))).whereType<TopicNote>().toList();
    return e.subjects
        .map((sid) => repo.subject(sid))
        .whereType<Subject>()
        .expand((s) => s.topics.map((t) => repo.note(s.id, t.id)))
        .whereType<TopicNote>()
        .toList();
  }

  Question _weightedQuestion(List<Question> pool) {
    final weak = quiz
        .topicStats()
        .where((t) => t.attempts >= 3 && t.accuracy < 0.7)
        .map((t) => '${t.subject}/${t.topic}')
        .toSet();
    final weakPool = pool.where((q) => weak.contains('${q.subject}/${q.topic}')).toList();
    if (weakPool.isNotEmpty && _rnd.nextDouble() < 0.5) return weakPool[_rnd.nextInt(weakPool.length)];
    return pool[_rnd.nextInt(pool.length)];
  }

  /// Generates [count] more items to append to a growing reel.
  List<ReelItem> more(int count) {
    final qPool = _questionPool();
    final cPool = _cardPool();
    final notes = _notePool();
    final motivations = repo.motivation;
    final items = <ReelItem>[];
    for (var i = 0; i < count; i++) {
      final roll = _rnd.nextDouble();
      if (roll < 0.55 && qPool.isNotEmpty) {
        items.add(ReelItem.question(_weightedQuestion(qPool)));
      } else if (roll < 0.75 && cPool.isNotEmpty) {
        items.add(ReelItem.flashcard(cPool[_rnd.nextInt(cPool.length)]));
      } else if (roll < 0.9 && notes.isNotEmpty) {
        final n = notes[_rnd.nextInt(notes.length)];
        if (n.factsMr.isNotEmpty) {
          final fi = _rnd.nextInt(n.factsMr.length);
          items.add(ReelItem.fact(
            Bi(n.factsMr[fi], fi < n.factsEn.length ? n.factsEn[fi] : n.factsMr[fi]),
            repo.subject(n.subject),
            repo.topic(n.subject, n.topic),
          ));
          continue;
        }
        if (motivations.isNotEmpty) items.add(ReelItem.motivation(motivations[_rnd.nextInt(motivations.length)]));
      } else if (motivations.isNotEmpty) {
        items.add(ReelItem.motivation(motivations[_rnd.nextInt(motivations.length)]));
      } else if (qPool.isNotEmpty) {
        items.add(ReelItem.question(_weightedQuestion(qPool)));
      }
    }
    return items;
  }
}
