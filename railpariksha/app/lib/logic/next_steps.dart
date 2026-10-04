import '../data/models.dart';
import 'quiz_builder.dart';

/// How a student did on one topic in the quiz they just finished, alongside
/// their all-time record there (which already includes this quiz's answers).
class TopicVerdict {
  final String subject;
  final String topic;
  final int sessionAttempts;
  final int sessionCorrect;
  final int totalAttempts;
  final int totalCorrect;
  const TopicVerdict(this.subject, this.topic, this.sessionAttempts, this.sessionCorrect, this.totalAttempts,
      this.totalCorrect);

  /// Accuracy used to rank topics: all-time when there's enough history, so one
  /// unlucky question in a well-practised topic doesn't flag it as weak.
  double get accuracy {
    final useTotal = totalAttempts >= sessionAttempts && totalAttempts >= 5;
    final a = useTotal ? totalAttempts : sessionAttempts;
    final c = useTotal ? totalCorrect : sessionCorrect;
    return a == 0 ? 0 : c / a;
  }

  bool get weak => sessionCorrect < sessionAttempts && accuracy < 0.6;
  bool get strong => sessionAttempts >= 2 && sessionCorrect == sessionAttempts && accuracy >= 0.8;
}

/// The end-of-quiz "Your next step" diagnosis: the topics to work on next
/// (weakest first) and the topic the student nailed (for encouragement).
class NextSteps {
  final List<TopicVerdict> weak;
  final TopicVerdict? strong;
  const NextSteps(this.weak, this.strong);

  bool get isEmpty => weak.isEmpty && strong == null;

  static const maxWeak = 3;

  /// [history] is the student's all-time per-topic record ([QuizBuilder.topicStats]).
  factory NextSteps.from(List<Question> questions, List<int?> answers, List<TopicStat> history) {
    final session = <String, List<int>>{};
    for (var i = 0; i < questions.length && i < answers.length; i++) {
      final a = answers[i];
      if (a == null) continue; // skipped questions say nothing about ability
      final q = questions[i];
      final s = session.putIfAbsent('${q.subject}/${q.topic}', () => [0, 0]);
      s[0]++;
      if (a == q.answer) s[1]++;
    }
    final hist = {for (final t in history) '${t.subject}/${t.topic}': t};
    final verdicts = [
      for (final e in session.entries)
        () {
          final p = e.key.split('/');
          final h = hist[e.key];
          return TopicVerdict(p[0], p[1], e.value[0], e.value[1], h?.attempts ?? 0, h?.correct ?? 0);
        }(),
    ];
    final weak = verdicts.where((v) => v.weak).toList()
      ..sort((a, b) {
        final c = a.accuracy.compareTo(b.accuracy);
        // Equal accuracy: the topic missed more often in this quiz comes first.
        return c != 0 ? c : (b.sessionAttempts - b.sessionCorrect).compareTo(a.sessionAttempts - a.sessionCorrect);
      });
    final strong = verdicts.where((v) => v.strong).toList()
      ..sort((a, b) => b.sessionAttempts.compareTo(a.sessionAttempts));
    return NextSteps(weak.take(maxWeak).toList(), strong.isEmpty ? null : strong.first);
  }
}
