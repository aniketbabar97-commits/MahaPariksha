import 'package:bharari/data/content_repo.dart';
import 'package:bharari/data/progress.dart';
import 'package:bharari/logic/quiz_builder.dart';
import 'package:bharari/logic/reel_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepo repo;

  setUpAll(() async {
    repo = ContentRepo();
    await repo.load();
  });

  test('the reel generates a non-empty mix of card kinds', () {
    final p = Progress()..examId = 'police_bharti';
    final b = ReelBuilder(repo, p, QuizBuilder(repo, p));
    final batch = b.more(60);
    expect(batch.length, 60);
    final kinds = batch.map((i) => i.kind).toSet();
    // With 60 draws the random mix should hit at least question + one other kind.
    expect(kinds.contains(ReelKind.question), isTrue);
    expect(kinds.length, greaterThan(1));
  });

  test('every generated item carries the payload matching its kind', () {
    final p = Progress()..examId = 'mpsc_rajyaseva';
    final b = ReelBuilder(repo, p, QuizBuilder(repo, p));
    for (final item in b.more(80)) {
      switch (item.kind) {
        case ReelKind.question:
          expect(item.question, isNotNull);
        case ReelKind.flashcard:
          expect(item.flashcard, isNotNull);
        case ReelKind.fact:
          expect(item.fact, isNotNull);
        case ReelKind.motivation:
          expect(item.motivation, isNotNull);
        case ReelKind.adSlot:
          expect(item.question, isNull);
          expect(item.flashcard, isNull);
      }
    }
  });

  test('the reel keeps generating even with no exam selected (uses the full bank)', () {
    final p = Progress();
    final b = ReelBuilder(repo, p, QuizBuilder(repo, p));
    expect(b.more(30).length, 30);
  });

  test('an ad slot appears exactly every 8th card', () {
    final p = Progress()..examId = 'police_bharti';
    final b = ReelBuilder(repo, p, QuizBuilder(repo, p));
    final batch = b.more(40);
    for (var i = 0; i < batch.length; i++) {
      final isAdPosition = (i + 1) % ReelBuilder.adEvery == 0;
      expect(batch[i].kind == ReelKind.adSlot, isAdPosition, reason: 'index $i');
    }
  });

  test('reel questions respect the reported-question exclusion', () {
    final p = Progress()..examId = 'police_bharti';
    final b = ReelBuilder(repo, p, QuizBuilder(repo, p));
    final someId = repo.questionsFor(repo.exam('police_bharti')!).first.id;
    p.report(someId);
    final batch = b.more(200);
    expect(batch.any((i) => i.kind == ReelKind.question && i.question!.id == someId), isFalse);
  });
}
