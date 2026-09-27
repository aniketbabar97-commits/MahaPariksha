import 'dart:math';

import '../data/models.dart';

/// The real Dubai RTA computer-based theory test format this mode
/// replicates: 35 questions, a 30-minute timer, and a 65% (23/35) pass mark.
const int kMockExamQuestionCount = 35;
const Duration kMockExamDuration = Duration(minutes: 30);
const int kMockExamPassCount = 23; // 23/35 ≈ 65.7%, i.e. the ~65% pass bar.

/// Roughly how a real theory test weights each syllabus category, used to
/// build a realistic mock exam rather than a uniform random sample. Weights
/// are a study heuristic (heavier on signs/right-of-way, as most learner
/// feedback and the reviewed competitor sites describe), not an official
/// RTA-published breakdown.
const Map<String, int> mockExamCategoryWeights = {
  'road_signs': 8,
  'traffic_rules_row': 6,
  'highway_lane': 4,
  'roundabouts_intersections': 4,
  'speed_limits': 3,
  'fines_penalty': 3,
  'alcohol_fatigue': 2,
  'seatbelt_child_safety': 2,
  'parking_rules': 2,
  'vehicle_docs_insurance': 1,
};

/// Builds a randomized [kMockExamQuestionCount]-question exam from [pool],
/// weighted per [mockExamCategoryWeights] where the pool has enough
/// questions in that category, then top-filled from whatever remains so a
/// small content bank still produces a full-length exam.
List<Question> buildMockExam(List<Question> pool, {Random? random}) {
  final rnd = random ?? Random();
  final byCategory = <String, List<Question>>{};
  for (final q in pool) {
    byCategory.putIfAbsent(q.category, () => []).add(q);
  }
  for (final list in byCategory.values) {
    list.shuffle(rnd);
  }

  final selected = <Question>[];
  final used = <String>{};

  mockExamCategoryWeights.forEach((category, weight) {
    final available = byCategory[category] ?? const [];
    final take = min(weight, available.length);
    for (int i = 0; i < take; i++) {
      selected.add(available[i]);
      used.add(available[i].id);
    }
  });

  if (selected.length < kMockExamQuestionCount) {
    final remaining = pool.where((q) => !used.contains(q.id)).toList()..shuffle(rnd);
    for (final q in remaining) {
      if (selected.length >= kMockExamQuestionCount) break;
      selected.add(q);
      used.add(q.id);
    }
  }

  selected.shuffle(rnd);
  return selected.length > kMockExamQuestionCount ? selected.sublist(0, kMockExamQuestionCount) : selected;
}

/// A single answered (or unanswered, if timed out) exam question outcome.
class MockExamAnswer {
  final Question question;
  final int? selected;
  bool get isCorrect => selected != null && selected == question.answer;
  const MockExamAnswer(this.question, this.selected);
}

/// Aggregates exam answers into a per-category right/wrong breakdown for the
/// results screen's "weak area" view.
class CategoryBreakdown {
  final String category;
  final int correct;
  final int total;
  const CategoryBreakdown(this.category, this.correct, this.total);
  double get ratio => total == 0 ? 0 : correct / total;
}

List<CategoryBreakdown> summarizeByCategory(List<MockExamAnswer> answers) {
  final byCategory = <String, List<MockExamAnswer>>{};
  for (final a in answers) {
    byCategory.putIfAbsent(a.question.category, () => []).add(a);
  }
  final result = byCategory.entries
      .map((e) => CategoryBreakdown(e.key, e.value.where((a) => a.isCorrect).length, e.value.length))
      .toList()
    ..sort((a, b) => a.ratio.compareTo(b.ratio)); // weakest first
  return result;
}
