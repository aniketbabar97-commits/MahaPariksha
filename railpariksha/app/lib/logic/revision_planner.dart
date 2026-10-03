import '../data/progress.dart';
import 'quiz_builder.dart';

/// The three stages of exam prep, purely a function of [Progress.daysToExam] --
/// never stored, so the plan can never drift out of sync if the user changes
/// their exam date or the days simply tick down.
enum RevisionPhase { foundation, weakFocus, finalRevision }

/// How many days out each phase starts, counting down to exam day. Deliberately
/// generous on the foundation window and tight on final revision: cramming new
/// topics in the last few days is the single most common mistake aspirants make,
/// so the plan pushes hard toward pure revision once the exam is close.
class RevisionPlanner {
  final QuizBuilder builder;
  const RevisionPlanner(this.builder);

  static const foundationFrom = 21; // > this many days left: still building foundations
  static const weakFocusFrom = 6; // > this many days left (and <= foundationFrom): weak-topic focus

  Progress get progress => builder.progress;

  /// Null when no exam date is set -- there's no countdown to phase against yet.
  RevisionPhase? get phase {
    final d = progress.daysToExam;
    if (d == null) return null;
    if (d >= foundationFrom) return RevisionPhase.foundation;
    if (d >= weakFocusFrom) return RevisionPhase.weakFocus;
    return RevisionPhase.finalRevision;
  }
}
