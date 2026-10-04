import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/models.dart';
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

  group('adaptive practice', () {
    late ContentRepo repo;

    setUpAll(() async {
      repo = ContentRepo();
      await repo.load();
    });

    test('mastery levels follow accuracy once there is enough history', () {
      expect(Mastery.of(2, 1.0), Mastery.newcomer);
      expect(Mastery.of(10, 0.3), Mastery.building);
      expect(Mastery.of(10, 0.6), Mastery.steady);
      expect(Mastery.of(10, 0.9), Mastery.strong);
    });

    Map<int, int> tierCounts(List<Question> qs) {
      final c = {1: 0, 2: 0, 3: 0};
      for (final q in qs) {
        final d = q.difficulty.clamp(1, 3);
        c[d] = c[d]! + 1;
      }
      return c;
    }

    test('a strong learner gets harder sets than a struggling one', () {
      const subject = 'maths', topic = 'percentage';
      final topicQs = repo.questions.where((q) => q.subject == subject && q.topic == topic).toList();

      Progress withAccuracy(double acc) {
        final p = Progress();
        for (var i = 0; i < 20; i++) {
          p.qStats[topicQs[i].id] = [1, i < acc * 20 ? 1 : 0, 0];
        }
        return p;
      }

      final strong = QuizBuilder(repo, withAccuracy(0.95));
      final weak = QuizBuilder(repo, withAccuracy(0.2));
      expect(strong.mastery(subject, topic), Mastery.strong);
      expect(weak.mastery(subject, topic), Mastery.building);

      final strongSet = strong.practice(subject: subject, topic: topic, count: 10).questions;
      final weakSet = weak.practice(subject: subject, topic: topic, count: 10).questions;
      expect(strongSet, hasLength(10));
      expect(weakSet, hasLength(10));
      expect(tierCounts(strongSet)[3]!, greaterThan(tierCounts(weakSet)[3]!));
      expect(tierCounts(weakSet)[1]!, greaterThan(tierCounts(strongSet)[1]!));
    });

    test('practice sets warm up easy-to-hard', () {
      final qs = QuizBuilder(repo, Progress()).practice(subject: 'maths', topic: 'percentage', count: 10).questions;
      final diffs = [for (final q in qs) q.difficulty.clamp(1, 3)];
      expect(diffs, [...diffs]..sort());
    });
  });
}
