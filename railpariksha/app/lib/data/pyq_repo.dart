import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/services.dart';

import 'models.dart';

/// One previous-year paper (a single exam shift), e.g.
/// "RRB JE CBT-1 2025 · 19 Feb 2026 · Shift 1".
class PyqPaper {
  final String label;
  final int count;
  const PyqPaper(this.label, this.count);

  /// The part after the exam/year, e.g. "19 Feb 2026 · Shift 1" (empty when the
  /// source didn't record the date/shift).
  String get shortLabel {
    final i = label.indexOf(' · ');
    return i < 0 ? '' : label.substring(i + 3);
  }
}

/// All of one exam's questions from one year, shipped as its own asset file.
class PyqSet {
  final String exam;
  final int year;

  /// A railway (RRB/RPF) paper, as opposed to a same-syllabus non-railway exam (SSC).
  final bool railway;
  final String file;
  final int count;
  final Map<String, int> subjects;
  final List<PyqPaper> papers;
  const PyqSet(this.exam, this.year, this.railway, this.file, this.count, this.subjects, this.papers);

  String get title => '$exam $year';

  factory PyqSet.fromJson(Map<String, dynamic> j) => PyqSet(
        j['exam'],
        j['year'],
        j['rail'] == true,
        j['file'],
        j['n'],
        Map<String, int>.from(j['subjects']),
        [for (final p in j['papers']) PyqPaper(p['label'], p['n'])],
      );
}

/// Every PYQ of one topic, shipped as its own small file (see build_bundle.py).
class PyqTopic {
  final String subject;
  final String topic;
  final int count;
  final String file;

  /// Question count per exam name ("RRB NTPC Graduate CBT-1" -> 812).
  final Map<String, int> byExam;
  const PyqTopic(this.subject, this.topic, this.count, this.file, this.byExam);

  /// Questions in this topic from exams whose name starts with [prefix] ("RRB NTPC"), or all if null.
  int countFor(String? prefix) => prefix == null
      ? count
      : byExam.entries.where((e) => e.key.startsWith(prefix)).fold(0, (a, e) => a + e.value);

  factory PyqTopic.fromJson(Map<String, dynamic> j) =>
      PyqTopic(j['s'], j['t'], j['n'], j['file'], Map<String, int>.from(j['by_exam']));
}

/// Previous-year questions live outside the main content pack (~80k of them, from
/// English-only sources) so they cost nothing at launch: the small index loads when
/// the PYQ section opens, and each exam/year file only when that set is opened.
class PyqRepo {
  static const _dir = 'assets/pyq';

  final AssetBundle _bundle;
  PyqRepo([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  List<PyqSet>? _sets;
  List<PyqTopic>? _topics;
  final Map<String, List<Question>> _loaded = {};

  /// The set index, or an empty list if this build has no PYQ pack.
  Future<List<PyqSet>> sets() async {
    if (_sets != null) return _sets!;
    try {
      final j = jsonDecode(await _bundle.loadString('$_dir/index.json')) as Map<String, dynamic>;
      // A 'year' with only a handful of stray questions is noise, not a paper students can practise.
      _sets = [for (final s in j['sets']) PyqSet.fromJson(s)].where((s) => s.count >= 20).toList();
      _topics = [for (final t in (j['topics'] as List? ?? const [])) PyqTopic.fromJson(t)];
    } catch (_) {
      _sets = const [];
      _topics = const [];
    }
    return _sets!;
  }

  /// The topic index (empty if this build has no PYQ pack).
  Future<List<PyqTopic>> topics() async {
    await sets();
    return _topics ?? const [];
  }

  /// Every question of [topic], from all exams. Callers filter by `Question.pyq` prefix.
  Future<List<Question>> topicQuestions(PyqTopic topic) async {
    final cached = _loaded[topic.file];
    if (cached != null) return cached;
    final raw = await _bundle.loadString('$_dir/${topic.file}');
    final qs = await Isolate.run(() => [
          for (final q in jsonDecode(raw) as List) Question.fromJson(q as Map<String, dynamic>),
        ]);
    if (_loaded.length >= 3) _loaded.remove(_loaded.keys.first);
    return _loaded[topic.file] = qs;
  }

  /// A random draw of previous-year questions for an exam: [quota] questions per subject, taken
  /// from [candidates] (the exam's sets) a few at a time, so a full 100-question exam reads two or
  /// three year-files rather than the whole pack. [accept] filters (language, exam name).
  /// Subjects with too few questions in the sampled sets are topped up from the remaining sets.
  Future<Map<String, List<Question>>> sampleBySubject(
    List<PyqSet> candidates,
    Map<String, int> quota, {
    bool Function(Question q)? accept,
    Random? random,
  }) async {
    final rnd = random ?? Random();
    final order = [...candidates]..shuffle(rnd);
    final pool = {for (final s in quota.keys) s: <Question>[]};
    for (final set in order) {
      // Done when every subject has plenty to choose from (3x its quota).
      if (quota.entries.every((e) => pool[e.key]!.length >= e.value * 3)) break;
      for (final q in await questions(set)) {
        final list = pool[q.subject];
        if (list != null && (accept == null || accept(q))) list.add(q);
      }
    }
    return {
      for (final e in quota.entries) e.key: (pool[e.key]!..shuffle(rnd)).take(e.value).toList(),
    };
  }

  /// Every question in [set]. Decoded off the UI isolate (a set can be a few MB).
  Future<List<Question>> questions(PyqSet set) async {
    final cached = _loaded[set.file];
    if (cached != null) return cached;
    final raw = await _bundle.loadString('$_dir/${set.file}');
    final qs = await Isolate.run(() => [
          for (final q in jsonDecode(raw) as List) Question.fromJson(q as Map<String, dynamic>),
        ]);
    // Keep only the most recently opened few sets in memory.
    if (_loaded.length >= 3) _loaded.remove(_loaded.keys.first);
    return _loaded[set.file] = qs;
  }
}
