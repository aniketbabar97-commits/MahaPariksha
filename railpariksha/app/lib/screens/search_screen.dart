import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../logic/quiz_builder.dart';
import '../widgets/common.dart';
import 'quiz_screen.dart';
import 'topic_screen.dart';

/// Search across the current exam's question bank and topic notes.
///
/// Filtering is a plain case-insensitive substring scan over `questionsFor(exam)`
/// (already precomputed by ContentRepo) and over all notes narrowed to the exam's
/// subjects. Input is debounced so the scan runs once per pause in typing rather
/// than on every keystroke, which keeps this smooth even as the bank grows toward
/// 20,000+ questions.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Cheap listener: only rebuilds the app bar's clear button immediately.
    // The actual filtering below runs off `_query`, which only changes once
    // the debounce timer fires.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _query = v.trim());
    });
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final exam = s.builder.exam;
    if (exam == null) return const NoExamState();

    final needle = _query.toLowerCase();
    List<Question> questionResults = const [];
    List<TopicNote> noteResults = const [];
    if (needle.isNotEmpty) {
      final pool = s.repo.questionsFor(exam);
      questionResults = pool
          .where((q) => q.text.hi.toLowerCase().contains(needle) || q.text.en.toLowerCase().contains(needle))
          .take(50)
          .toList();
      final examSubjects = exam.subjects.toSet();
      noteResults = s.repo.allNotes
          .where((n) =>
              examSubjects.contains(n.subject) &&
              (n.summary.hi.toLowerCase().contains(needle) ||
                  n.summary.en.toLowerCase().contains(needle) ||
                  n.factsHi.any((f) => f.toLowerCase().contains(needle)) ||
                  n.factsEn.any((f) => f.toLowerCase().contains(needle))))
          .take(20)
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: context.tr('प्रश्न या टॉपिक खोजें…', 'Search questions or topics…'),
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(icon: const Icon(Icons.clear), tooltip: context.tr('साफ़ करें', 'Clear'), onPressed: _clear),
        ],
      ),
      body: _query.isEmpty
          ? EmptyState(
              icon: Icons.search,
              text: context.tr('टाइप करना शुरू करें — हिंदी या अंग्रेज़ी में।', 'Start typing — in Hindi or English.'),
            )
          : (questionResults.isEmpty && noteResults.isEmpty)
              ? EmptyState(
                  icon: Icons.search_off,
                  text: context.tr('कुछ नहीं मिला। कोई और शब्द आज़माएं।', 'No results. Try a different search term.'),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    if (noteResults.isNotEmpty) ...[
                      SectionTitle(context.tr('नोट्स', 'Notes')),
                      for (final n in noteResults) ...[
                        _NoteResultTile(note: n),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if (questionResults.isNotEmpty) ...[
                      SectionTitle(context.tr('प्रश्न (${questionResults.length})', 'Questions (${questionResults.length})')),
                      for (final q in questionResults) ...[
                        _QuestionResultTile(question: q),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
    );
  }
}

class _QuestionResultTile extends StatelessWidget {
  final Question question;
  const _QuestionResultTile({required this.question});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final lang = context.lang;
    final subject = s.repo.subject(question.subject);
    final topic = s.repo.topic(question.subject, question.topic);
    final label = [subject?.name.of(lang), topic?.name.of(lang)].whereType<String>().join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuizScreen(
              spec: QuizSpec(
                QuizMode.practice,
                [question],
                label.isEmpty ? 'प्रश्न' : label,
                label.isEmpty ? 'Question' : label,
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: BrandColors.sky.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(subjectIcon(subject?.icon ?? ''), color: BrandColors.sky, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (label.isNotEmpty)
                  Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(question.text.of(lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.35)),
              ]),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
          ]),
        ),
      ),
    );
  }
}

class _NoteResultTile extends StatelessWidget {
  final TopicNote note;
  const _NoteResultTile({required this.note});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final lang = context.lang;
    final subject = s.repo.subject(note.subject);
    final topic = s.repo.topic(note.subject, note.topic);
    if (subject == null || topic == null) return const SizedBox.shrink();
    final label = '${subject.name.of(lang)} · ${topic.name.of(lang)}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicScreen(subject: subject, topic: topic))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: BrandColors.correct.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.edit_note, color: BrandColors.correct, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(note.summary.of(lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.35)),
              ]),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
          ]),
        ),
      ),
    );
  }
}
