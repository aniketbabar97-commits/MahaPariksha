import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Remote content pack. Empty disables updates; the bundled pack is always the fallback.
const String kContentUrl = String.fromEnvironment('CONTENT_URL');

class ContentRepo {
  int version = 0;
  final List<Subject> subjects = [];
  final List<Exam> exams = [];
  final List<ExamGroup> groups = [];
  final List<Question> questions = [];
  final List<Flashcard> flashcards = [];
  final List<Motivation> motivation = [];
  final Map<String, TopicNote> _notes = {};
  final Map<String, ExamStrategy> _strategies = {};
  List<GkBoosterCategory> gkBooster = [];

  TopicNote? note(String subject, String topic) => _notes['$subject/$topic'];
  bool hasNotes(String subject) => _notes.keys.any((k) => k.startsWith('$subject/'));

  ExamStrategy? strategy(String examId) => _strategies[examId];

  /// A subject's cram cheat sheets, in file order (one entry per category,
  /// e.g. Percentage, Mensuration). Empty for a subject with none yet.
  List<CheatSheet> cheatSheetsFor(String subject) =>
      _cheatSheetsBySubject[subject] ?? const [];
  bool hasCheatSheets(String subject) => (_cheatSheetsBySubject[subject] ?? const []).isNotEmpty;
  final List<CheatSheet> _cheatSheets = [];
  final Map<String, List<CheatSheet>> _cheatSheetsBySubject = {};

  /// All topic notes, unordered. Notes aren't indexed by exam (a note is keyed by
  /// subject/topic, not exam), so callers that need exam-scoped notes filter this
  /// by subject id themselves (e.g. the search screen).
  List<TopicNote> get allNotes => _notes.values.toList(growable: false);

  final Map<String, Subject> _subjectById = {};
  final Map<String, Exam> _examById = {};
  final Map<String, Question> _questionById = {};

  // Precomputed once in _apply() so subjectsFor/questionsFor/flashcardsFor don't
  // rescan the full question/flashcard lists on every call (those are invoked from
  // screen build() methods, so at 20,000+ questions a linear scan there would jank).
  final Map<String, List<Question>> _questionsBySubject = {};
  final Map<String, int> _topicQuestionCounts = {};
  final Map<String, List<Flashcard>> _flashcardsBySubject = {};

  /// Whether this subject has ANY flashcards at all, regardless of what's due
  /// today. A newly-added subject (before flashcards are generated for it)
  /// has none -- distinct from "has cards, just none due right now", which
  /// callers should tell apart in their empty-state copy.
  bool hasFlashcards(String subject) => (_flashcardsBySubject[subject] ?? const []).isNotEmpty;

  Subject? subject(String id) => _subjectById[id];
  Exam? exam(String id) => _examById[id];
  Question? question(String id) => _questionById[id];

  Topic? topic(String subjectId, String topicId) {
    for (final t in _subjectById[subjectId]?.topics ?? const <Topic>[]) {
      if (t.id == topicId) return t;
    }
    return null;
  }

  List<Subject> subjectsFor(Exam e) => e.subjects
      .map((s) => _subjectById[s])
      .whereType<Subject>()
      .where((s) => (_questionsBySubject[s.id] ?? const []).isNotEmpty)
      .toList();

  /// One subject's questions, from the precomputed index (safe in build()).
  List<Question> questionsInSubject(String subject) => _questionsBySubject[subject] ?? const [];

  int topicQuestionCount(String subject, String topic) => _topicQuestionCounts['$subject/$topic'] ?? 0;

  List<Question> questionsFor(Exam e) =>
      [for (final s in e.subjects) ...?_questionsBySubject[s]];

  List<Flashcard> flashcardsFor(Exam e) =>
      [for (final s in e.subjects) ...?_flashcardsBySubject[s]];

  Future<File> _cacheFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/content.json');

  Future<void> load() async {
    final bundled = await rootBundle.loadString('assets/content/bundle.json');
    String? cached;
    try {
      final f = await _cacheFile();
      if (await f.exists()) cached = await f.readAsString();
    } catch (_) {
      // Unreadable cache: the bundled pack is always the fallback.
    }
    // The pack is ~28 MB; decoding it on the UI isolate stalls launch on
    // budget phones, so it happens in the background.
    _apply(await Isolate.run(() => decodeNewestPack(bundled, cached)));
  }

  static final _versionHeader = RegExp(r'^\s*\{\s*"version"\s*:\s*(\d+)');

  /// Reads a pack's version from its leading `{"version":N` without decoding
  /// the whole document. Null when the pack doesn't start that way.
  static int? peekVersion(String pack) =>
      int.tryParse(_versionHeader.firstMatch(pack.length > 64 ? pack.substring(0, 64) : pack)?.group(1) ?? '');

  /// Decodes whichever of the bundled/cached packs is newer -- only that one,
  /// so a stale cache never costs a second full decode.
  static Map<String, dynamic> decodeNewestPack(String bundled, String? cached) {
    final bundledVersion = peekVersion(bundled) ?? 0;
    final cachedVersion = cached == null ? null : peekVersion(cached);
    if (cached != null && (cachedVersion == null || cachedVersion > bundledVersion)) {
      try {
        final c = jsonDecode(cached) as Map<String, dynamic>;
        if (((c['version'] as num?) ?? 0) > bundledVersion) return c;
      } catch (_) {
        // Corrupt cache: fall back to the bundled pack.
      }
    }
    return jsonDecode(bundled) as Map<String, dynamic>;
  }

  /// Returns true when a newer pack was downloaded (applied on next launch).
  Future<bool> checkForUpdate() async {
    if (kContentUrl.isEmpty) return false;
    try {
      final res = await http.get(Uri.parse(kContentUrl)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return false;
      final bytes = res.bodyBytes;
      // Validate the full download off the UI isolate: this runs while the
      // user is using the app, where a ~28 MB decode would visibly jank.
      final (body, remoteVersion) = await Isolate.run(() {
        final b = utf8.decode(bytes);
        final d = jsonDecode(b) as Map<String, dynamic>;
        return (b, (d['version'] as num?)?.toInt() ?? 0);
      });
      if (remoteVersion <= version) return false;
      await (await _cacheFile()).writeAsString(body);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _apply(Map<String, dynamic> data) {
    version = data['version'] ?? 0;
    final tax = data['taxonomy'];
    subjects
      ..clear()
      ..addAll((tax['subjects'] as List).map((s) => Subject(
            s['id'],
            Bi(s['hi'], s['en']),
            s['icon'] ?? 'book',
            (s['topics'] as List)
                .map((t) => Topic(t['id'], s['id'], Bi(t['hi'], t['en'])))
                .toList(),
          )));
    exams
      ..clear()
      ..addAll((tax['exams'] as List).map((e) {
        final subjectEntries = (e['subjects'] as List).cast<Map<String, dynamic>>();
        return Exam(
          e['id'],
          e['group'],
          Bi(e['hi'], e['en']),
          subjectEntries.map((s) => s['id'] as String).toList(),
          {for (final s in subjectEntries) s['id'] as String: (s['w'] as num?)?.toInt() ?? 1},
          (e['neg'] as num? ?? 0).toDouble(),
          (e['paper_q'] as num?)?.toInt(),
          (e['paper_min'] as num?)?.toInt(),
        );
      }));
    groups
      ..clear()
      ..addAll((tax['exam_groups'] as List).map((g) => ExamGroup(g['id'], Bi(g['hi'], g['en']))));
    questions
      ..clear()
      ..addAll((data['questions'] as List).map((j) => Question.fromJson(j)));
    flashcards
      ..clear()
      ..addAll((data['flashcards'] as List).map((j) => Flashcard.fromJson(j)));
    motivation
      ..clear()
      ..addAll((data['motivation'] as List).map((j) => Motivation.fromJson(j)));

    _notes
      ..clear()
      ..addEntries(((data['notes'] as List?) ?? const [])
          .map((j) => TopicNote.fromJson(j))
          .map((n) => MapEntry('${n.subject}/${n.topic}', n)));
    final strategyJson = (data['exam_strategy'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    _strategies
      ..clear()
      ..addEntries(strategyJson.entries
          .map((e) => MapEntry(e.key, ExamStrategy.fromJson(e.key, e.value as Map<String, dynamic>))));
    final boosterRaw = data['gk_booster'];
    gkBooster = boosterRaw == null
        ? const []
        : ((boosterRaw['categories'] as List?) ?? const [])
            .map((j) => GkBoosterCategory.fromJson(j))
            .toList();
    _cheatSheets
      ..clear()
      ..addAll(((data['cheat_sheets'] as List?) ?? const []).map((j) => CheatSheet.fromJson(j)));
    _cheatSheetsBySubject.clear();
    for (final c in _cheatSheets) {
      (_cheatSheetsBySubject[c.subject] ??= []).add(c);
    }
    _subjectById
      ..clear()
      ..addEntries(subjects.map((s) => MapEntry(s.id, s)));
    _examById
      ..clear()
      ..addEntries(exams.map((e) => MapEntry(e.id, e)));
    _questionById
      ..clear()
      ..addEntries(questions.map((q) => MapEntry(q.id, q)));
    _questionsBySubject.clear();
    _topicQuestionCounts.clear();
    for (final q in questions) {
      (_questionsBySubject[q.subject] ??= []).add(q);
      _topicQuestionCounts.update('${q.subject}/${q.topic}', (n) => n + 1, ifAbsent: () => 1);
    }
    _flashcardsBySubject.clear();
    for (final c in flashcards) {
      (_flashcardsBySubject[c.subject] ??= []).add(c);
    }
  }
}
