import 'quiz_builder.dart';

class SubjectBreakdown {
  final String subject;
  int total = 0;
  int attempted = 0;
  int correct = 0;
  Duration time = Duration.zero;
  SubjectBreakdown(this.subject);

  int get wrong => attempted - correct;
  double accuracy() => attempted == 0 ? 0 : correct / attempted;
  double net(double negative) => correct - wrong * negative;
}

enum StrategyTip { overAttempting, underAttempting }

/// Post-test diagnosis of a mock: where marks were won and lost, and what to
/// change next time. Pure so it can be unit tested without widgets.
class MockAnalysis {
  final List<SubjectBreakdown> subjects;
  final int total;
  final int attempted;
  final int correct;
  final double negative;

  /// Question indices that took notably longer than this attempt's average.
  final List<int> slowest;
  final Duration? avgTime;

  /// The exam's own time budget per question, when the test is timed.
  final Duration? targetPace;
  final StrategyTip? tip;

  const MockAnalysis._(this.subjects, this.total, this.attempted, this.correct, this.negative, this.slowest, this.avgTime,
      this.targetPace, this.tip);

  int get wrong => attempted - correct;
  double get marksLostToNegative => wrong * negative;

  factory MockAnalysis.from(QuizSpec spec, List<int?> answers, List<Duration>? times) {
    final bySubject = <String, SubjectBreakdown>{};
    var attempted = 0, correct = 0;
    for (var i = 0; i < spec.questions.length; i++) {
      final q = spec.questions[i];
      final b = bySubject.putIfAbsent(q.subject, () => SubjectBreakdown(q.subject));
      b.total++;
      if (times != null && i < times.length) b.time += times[i];
      final a = answers[i];
      if (a == null) continue;
      b.attempted++;
      attempted++;
      if (a == q.answer) {
        b.correct++;
        correct++;
      }
    }
    final subjects = bySubject.values.toList()..sort((a, b) => b.total.compareTo(a.total));

    Duration? avg;
    final slowest = <int>[];
    if (times != null && times.isNotEmpty) {
      final totalMs = times.fold<int>(0, (s, d) => s + d.inMilliseconds);
      avg = Duration(milliseconds: totalMs ~/ times.length);
      final order = [for (var i = 0; i < times.length; i++) i]..sort((a, b) => times[b].compareTo(times[a]));
      for (final i in order.take(3)) {
        if (times[i].inSeconds >= 20 && times[i].inMilliseconds >= avg.inMilliseconds * 1.5) slowest.add(i);
      }
    }

    final limit = spec.timeLimit;
    final pace = limit == null || spec.questions.isEmpty ? null : Duration(milliseconds: limit.inMilliseconds ~/ spec.questions.length);

    StrategyTip? tip;
    final n = spec.questions.length;
    if (spec.negative > 0 && n > 0 && attempted >= 5) {
      final accuracy = correct / attempted;
      final skippedShare = (n - attempted) / n;
      if (attempted - correct >= 3 && accuracy < 0.5) {
        tip = StrategyTip.overAttempting;
      } else if (skippedShare >= 0.2 && accuracy >= 0.8) {
        tip = StrategyTip.underAttempting;
      }
    }
    return MockAnalysis._(subjects, n, attempted, correct, spec.negative, slowest, avg, pace, tip);
  }
}
