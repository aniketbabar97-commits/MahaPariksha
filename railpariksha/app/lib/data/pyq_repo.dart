import 'dart:convert';
import 'dart:isolate';

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

/// Previous-year questions live outside the main content pack (~80k of them, from
/// English-only sources) so they cost nothing at launch: the small index loads when
/// the PYQ section opens, and each exam/year file only when that set is opened.
class PyqRepo {
  static const _dir = 'assets/pyq';

  final AssetBundle _bundle;
  PyqRepo([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  List<PyqSet>? _sets;
  final Map<String, List<Question>> _loaded = {};

  /// The set index, or an empty list if this build has no PYQ pack.
  Future<List<PyqSet>> sets() async {
    if (_sets != null) return _sets!;
    try {
      final j = jsonDecode(await _bundle.loadString('$_dir/index.json')) as Map<String, dynamic>;
      _sets = [for (final s in j['sets']) PyqSet.fromJson(s)];
    } catch (_) {
      _sets = const [];
    }
    return _sets!;
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
