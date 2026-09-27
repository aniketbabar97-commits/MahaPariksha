import '../data/models.dart';
import '../data/prefs.dart';

/// A flashcard derived from a question bank entry: front = the question
/// text, back = the correct answer + explanation. No separate content
/// authoring is needed — cards are generated from the existing bank.
class Flashcard {
  final String id;
  final String category;
  final String front;
  final String back;
  const Flashcard({required this.id, required this.category, required this.front, required this.back});

  factory Flashcard.fromQuestion(Question q, String lang) {
    final answerText = q.options[q.answer].resolve(lang).text;
    final explanation = q.explanation.resolve(lang).text;
    return Flashcard(
      id: q.id,
      category: q.category,
      front: q.q.resolve(lang).text,
      back: '$answerText\n\n$explanation',
    );
  }
}

/// Per-card scheduling state for a light SM-2-style spaced repetition
/// scheduler (simplified: 3 quality buckets via a boolean "knew it", ease
/// factor bounded to [1.3, 2.8], and day-granularity intervals).
class _CardState {
  int reps;
  double ease;
  int intervalDays;
  DateTime due;

  _CardState({required this.reps, required this.ease, required this.intervalDays, required this.due});

  factory _CardState.fresh() => _CardState(reps: 0, ease: 2.5, intervalDays: 0, due: DateTime.now());

  factory _CardState.fromJson(Map<String, dynamic> j) => _CardState(
        reps: j['reps'] as int? ?? 0,
        ease: (j['ease'] as num?)?.toDouble() ?? 2.5,
        intervalDays: j['interval'] as int? ?? 0,
        due: DateTime.tryParse(j['due'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'reps': reps,
        'ease': ease,
        'interval': intervalDays,
        'due': due.toIso8601String(),
      };
}

/// Result of reviewing one card, used to drive celebratory/hint UI.
class ReviewResult {
  final bool knew;
  final int nextIntervalDays;
  const ReviewResult(this.knew, this.nextIntervalDays);
}

/// Loads/saves flashcard scheduling state and builds due decks. This is a
/// simplified SM-2: "knew it" = quality 4, "didn't know" = quality 1
/// (equivalent to Bharari's spaced-repetition flashcard concept, reimplemented
/// standalone here since Rukhsa keeps no shared code with Bharari).
class FlashcardScheduler {
  Map<String, dynamic> _raw = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _raw = await Prefs.getFlashcardState();
    _loaded = true;
  }

  Future<void> _save() => Prefs.setFlashcardState(_raw);

  _CardState _stateFor(String id) {
    final j = _raw[id];
    return j == null ? _CardState.fresh() : _CardState.fromJson(j as Map<String, dynamic>);
  }

  /// Returns cards due for review now (or never reviewed), most-overdue
  /// first, generated from [questions] and capped at [limit].
  Future<List<Flashcard>> dueCards(List<Question> questions, String lang, {int limit = 20}) async {
    await _ensureLoaded();
    final now = DateTime.now();
    final withDue = questions.map((q) => MapEntry(q, _stateFor(q.id))).where((e) => !e.value.due.isAfter(now)).toList()
      ..sort((a, b) => a.value.due.compareTo(b.value.due));
    return withDue.take(limit).map((e) => Flashcard.fromQuestion(e.key, lang)).toList();
  }

  /// Records a review outcome and reschedules the card (SM-2-lite):
  ///  - Didn't know: reset reps to 0, interval to 1 day, ease nudged down.
  ///  - Knew it: reps++, interval grows by the ease factor (1 -> 6 -> ease*prev),
  ///    ease nudged up slightly, capped to [1.3, 2.8].
  Future<ReviewResult> review(String cardId, bool knew) async {
    await _ensureLoaded();
    final s = _stateFor(cardId);
    if (knew) {
      s.reps += 1;
      s.ease = (s.ease + 0.1).clamp(1.3, 2.8);
      s.intervalDays = switch (s.reps) {
        1 => 1,
        2 => 6,
        _ => (s.intervalDays * s.ease).round().clamp(1, 365),
      };
    } else {
      s.reps = 0;
      s.ease = (s.ease - 0.2).clamp(1.3, 2.8);
      s.intervalDays = 1;
    }
    s.due = DateTime.now().add(Duration(days: s.intervalDays));
    _raw[cardId] = s.toJson();
    await _save();
    return ReviewResult(knew, s.intervalDays);
  }

  /// Count of cards currently due, for a home-screen badge.
  Future<int> dueCount(List<Question> questions) async {
    await _ensureLoaded();
    final now = DateTime.now();
    return questions.where((q) => !_stateFor(q.id).due.isAfter(now)).length;
  }
}
