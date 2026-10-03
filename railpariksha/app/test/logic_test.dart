import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/logic/percentile.dart';
import 'package:railpariksha/logic/quiz_builder.dart';
import 'package:railpariksha/logic/revision_planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('estimatedPercentile', () {
    test('is monotonic: a higher score never estimates a lower percentile', () {
      int? prev;
      for (var i = 0; i <= 20; i++) {
        final pct = estimatedPercentile(i / 20);
        if (prev != null) expect(pct, greaterThanOrEqualTo(prev));
        prev = pct;
      }
    });

    test('stays within the documented 1-99 band at the extremes', () {
      expect(estimatedPercentile(0.0), inInclusiveRange(1, 99));
      expect(estimatedPercentile(1.0), inInclusiveRange(1, 99));
      expect(estimatedPercentile(-5.0), 1); // clamped before use
      expect(estimatedPercentile(5.0), 99);
    });

    test('an average-looking score lands near the middle, not near either extreme', () {
      final pct = estimatedPercentile(0.45);
      expect(pct, inInclusiveRange(40, 60));
    });
  });

  group('RevisionPlanner', () {
    late ContentRepo repo;

    setUpAll(() async {
      repo = ContentRepo();
      await repo.load();
    });

    RevisionPlanner plannerWithDaysLeft(int? days) {
      final p = Progress()..examId = 'rrb_group_d';
      if (days != null) p.examDate = DateTime.now().add(Duration(days: days));
      return RevisionPlanner(QuizBuilder(repo, p));
    }

    test('no exam date set means no phase', () {
      expect(plannerWithDaysLeft(null).phase, isNull);
    });

    test('phase moves foundation -> weakFocus -> finalRevision as the countdown shrinks', () {
      expect(plannerWithDaysLeft(60).phase, RevisionPhase.foundation);
      expect(plannerWithDaysLeft(RevisionPlanner.foundationFrom).phase, RevisionPhase.foundation);
      expect(plannerWithDaysLeft(RevisionPlanner.foundationFrom - 1).phase, RevisionPhase.weakFocus);
      expect(plannerWithDaysLeft(RevisionPlanner.weakFocusFrom).phase, RevisionPhase.weakFocus);
      expect(plannerWithDaysLeft(RevisionPlanner.weakFocusFrom - 1).phase, RevisionPhase.finalRevision);
      expect(plannerWithDaysLeft(0).phase, RevisionPhase.finalRevision);
    });
  });
}
