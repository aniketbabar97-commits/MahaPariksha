import 'dart:convert';
import 'dart:io';

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

  TopicNote? note(String subject, String topic) => _notes['$subject/$topic'];
  bool hasNotes(String subject) => _notes.keys.any((k) => k.startsWith('$subject/'));

  final Map<String, Subject> _subjectById = {};
  final Map<String, Exam> _examById = {};
  final Map<String, Question> _questionById = {};

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
      .where((s) => questions.any((q) => q.subject == s.id))
      .toList();

  List<Question> questionsFor(Exam e) {
    final s = e.subjects.toSet();
    return questions.where((q) => s.contains(q.subject)).toList();
  }

  List<Flashcard> flashcardsFor(Exam e) {
    final s = e.subjects.toSet();
    return flashcards.where((c) => s.contains(c.subject)).toList();
  }

  Future<File> _cacheFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/content.json');

  Future<void> load() async {
    final bundled = await rootBundle.loadString('assets/content/bundle.json');
    Map<String, dynamic> data = jsonDecode(bundled);
    try {
      final f = await _cacheFile();
      if (await f.exists()) {
        final cached = jsonDecode(await f.readAsString());
        if ((cached['version'] ?? 0) > (data['version'] ?? 0)) data = cached;
      }
    } catch (_) {
      // Corrupt cache: fall back to the bundled pack.
    }
    _apply(data);
  }

  /// Returns true when a newer pack was downloaded (applied on next launch).
  Future<bool> checkForUpdate() async {
    if (kContentUrl.isEmpty) return false;
    try {
      final res = await http.get(Uri.parse(kContentUrl)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return false;
      final body = utf8.decode(res.bodyBytes);
      final data = jsonDecode(body);
      if ((data['version'] ?? 0) <= version) return false;
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
      ..addAll((tax['exams'] as List).map((e) =>
          Exam(e['id'], e['group'], Bi(e['hi'], e['en']), List<String>.from(e['subjects']),
          (e['neg'] as num? ?? 0).toDouble())));
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
    _subjectById
      ..clear()
      ..addEntries(subjects.map((s) => MapEntry(s.id, s)));
    _examById
      ..clear()
      ..addEntries(exams.map((e) => MapEntry(e.id, e)));
    _questionById
      ..clear()
      ..addEntries(questions.map((q) => MapEntry(q.id, q)));
  }
}
