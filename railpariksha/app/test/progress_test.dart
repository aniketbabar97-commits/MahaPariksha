import 'package:railpariksha/data/progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('streaks', () {
    test('first activity starts a streak of 1', () {
      final p = Progress();
      p.recordAnswer('q1', true);
      expect(p.streak, 1);
      expect(p.liveStreak, 1);
      expect(p.comeback, isFalse);
    });

    test('activity on consecutive days extends the streak', () {
      final p = Progress()
        ..lastActiveDay = today() - 1
        ..streak = 4;
      p.recordAnswer('q1', true);
      expect(p.streak, 5);
    });

    test('a freeze token covers one missed day', () {
      final p = Progress()
        ..lastActiveDay = today() - 2
        ..streak = 10
        ..freezeTokens = 1;
      p.recordAnswer('q1', false);
      expect(p.streak, 11);
      expect(p.freezeTokens, 0);
    });

    test('a longer gap restarts the streak and flags a comeback', () {
      final p = Progress()
        ..lastActiveDay = today() - 5
        ..streak = 30
        ..bestStreak = 30;
      p.recordAnswer('q1', true);
      expect(p.streak, 1);
      expect(p.comeback, isTrue);
      expect(p.bestStreak, 30);
    });

    test('a milestone is reported once, on the first activity of the day', () {
      final p = Progress()
        ..lastActiveDay = today() - 1
        ..streak = 6;
      expect(p.recordAnswer('q1', true).streakMilestone, 7);
      expect(p.recordAnswer('q2', true).streakMilestone, isNull);
      expect(p.freezeTokens, 1);
    });
  });

  group('xp, goal and levels', () {
    test('correct answers give more XP than wrong ones', () {
      final p = Progress();
      expect(p.recordAnswer('a', true).xp, 10);
      expect(p.recordAnswer('b', false).xp, 2);
    });

    test('reaching the daily goal pays a bonus exactly once', () {
      final p = Progress()..dailyGoal = 3;
      expect(p.recordAnswer('a', true).goalCompleted, isFalse);
      expect(p.recordAnswer('b', true).goalCompleted, isFalse);
      final r = p.recordAnswer('c', true);
      expect(r.goalCompleted, isTrue);
      expect(r.xp, 60);
      expect(p.recordAnswer('d', true).goalCompleted, isFalse);
      expect(p.goalProgress, 1.0);
    });

    test('level thresholds', () {
      final p = Progress();
      expect(p.level.en, 'General');
      p.xp = 300;
      expect(p.level.en, 'Sleeper');
      p.xp = 12000;
      expect(p.level.en, 'Rajdhani');
      expect(p.level.nextXp, 25000);
      p.xp = 25000;
      expect(p.level.en, 'Vande Bharat');
      expect(p.level.nextXp, isNull);
    });

    test('crossing a threshold reports a level-up', () {
      final p = Progress()..xp = 295;
      expect(p.recordAnswer('a', true).levelUp, isTrue);
    });
  });

  group('mistake book and stats', () {
    test('wrong answers enter the mistake book; a correct retry removes them', () {
      final p = Progress();
      p.recordAnswer('q', false);
      expect(p.mistakes, contains('q'));
      p.recordAnswer('q', true);
      expect(p.mistakes, isNot(contains('q')));
      expect(p.qStats['q'], [2, 1, 1]);
      expect(p.accuracy, 0.5);
    });

    test('reported questions are tracked', () {
      final p = Progress()..report('bad');
      expect(p.reported, contains('bad'));
    });
  });

  group('spaced repetition', () {
    test('good reviews grow the interval; again resets it', () {
      final p = Progress();
      p.reviewCard('c', true);
      expect(p.cards['c']!.interval, 1);
      p.reviewCard('c', true);
      expect(p.cards['c']!.interval, 3);
      p.reviewCard('c', true);
      expect(p.cards['c']!.interval, greaterThan(3));
      expect(p.cards['c']!.due, today() + p.cards['c']!.interval);
      p.reviewCard('c', false);
      expect(p.cards['c']!.interval, 0);
      expect(p.cards['c']!.due, today());
      expect(p.cards['c']!.ease, lessThan(2.6));
    });

    test('new and overdue cards count as due', () {
      final p = Progress();
      p.cards['later'] = CardState(due: today() + 5);
      p.cards['now'] = CardState(due: today() - 1);
      expect(p.dueCardCount(['later', 'now', 'new']), 2);
    });

    test('flashcard reviews do not count toward the question goal', () {
      final p = Progress();
      p.reviewCard('c', true);
      expect(p.todayCount, 0);
      expect(p.xp, 3);
    });
  });

  test('exam countdown', () {
    final p = Progress()..examDate = DateTime.now().add(const Duration(days: 10));
    expect(p.daysToExam, 10);
    p.examDate = DateTime.now().subtract(const Duration(days: 1));
    expect(p.daysToExam, isNull);
  });

  test('a paused mock survives a save/load JSON round trip', () {
    const m = PausedMock(
      examId: 'rrb_ntpc',
      questionIds: ['a', 'b', 'c'],
      titleHi: 'मॉक',
      titleEn: 'Mock',
      negative: 1 / 3,
      timeLimitSec: 600,
      remainingSec: 321,
      answers: [1, null, 3],
      marked: [1],
      visited: [0, 1, 2],
      index: 2,
      timeMs: [1000, 2000, 0],
    );
    final back = PausedMock.fromJson(m.toJson());
    expect(back.questionIds, m.questionIds);
    expect(back.answers, m.answers);
    expect(back.marked, m.marked);
    expect(back.remainingSec, 321);
    expect(back.answeredCount, 2);
  });

  group('rating prompt', () {
    Progress engaged() {
      final p = Progress()
        ..lastActiveDay = today()
        ..streak = 5;
      for (var i = 0; i < 120; i++) {
        p.qStats['q$i'] = [1, 1, 1];
      }
      return p;
    }

    test('asks an engaged learner after a good session', () {
      expect(engaged().shouldAskForReview(sessionScore: 0.8), isTrue);
    });

    test('never asks after a poor session, or a brand-new user', () {
      expect(engaged().shouldAskForReview(sessionScore: 0.5), isFalse);
      expect(Progress().shouldAskForReview(sessionScore: 1.0), isFalse);
    });

    test('waits 60 days between asks and stops after 3', () {
      final p = engaged()..markReviewAsked();
      expect(p.shouldAskForReview(sessionScore: 0.9), isFalse);
      p.lastReviewAskDay = today() - 60;
      expect(p.shouldAskForReview(sessionScore: 0.9), isTrue);
      p.reviewAsks = 3;
      expect(p.shouldAskForReview(sessionScore: 0.9), isFalse);
    });
  });

  group('ad-free hour and today mission', () {
    test('ad-free window hides ads without touching the purchase, then expires', () {
      final p = Progress();
      expect(p.removedAds, isFalse);
      p.grantAdFreeHour();
      expect(p.removedAds, isTrue);
      expect(p.premium, isFalse);
      expect(p.adFreeLeft.inMinutes, inInclusiveRange(58, 60));
      p.adFreeUntil = DateTime.now().subtract(const Duration(minutes: 1));
      expect(p.removedAds, isFalse);
      expect(p.adFreeActive, isFalse);
    });

    test('mission counters: CA read once a day, cards reviewed today', () {
      final p = Progress();
      expect(p.caReadToday, isFalse);
      p.markCaRead();
      expect(p.caReadToday, isTrue);
      expect(p.cardsReviewedToday, 0);
      p.reviewCard('c1', true);
      p.reviewCard('c2', false);
      expect(p.cardsReviewedToday, 2);
    });
  });
}
