import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'results_screen.dart';

class QuizScreen extends StatefulWidget {
  final String categoryId;
  const QuizScreen({super.key, required this.categoryId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<Question> _questions;
  int _index = 0;
  int? _selected;
  bool _revealed = false;
  final List<bool> _correctness = [];

  @override
  void initState() {
    super.initState();
    final bundle = AppScopeProvider.of(context).bundle!;
    _questions = bundle.byCategory(widget.categoryId);
  }

  Question get _current => _questions[_index];

  void _select(int optionIndex) {
    if (_revealed) return;
    setState(() {
      _selected = optionIndex;
      _revealed = true;
      _correctness.add(optionIndex == _current.answer);
    });
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            categoryId: widget.categoryId,
            correct: _correctness.where((c) => c).length,
            total: _questions.length,
          ),
        ),
      );
      return;
    }
    setState(() {
      _index += 1;
      _selected = null;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScopeProvider.of(context);
    final t = AppLocalizations.of(context);
    final lang = scope.lang;

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(t.categoriesTitle)),
        body: const Center(child: Text('No questions in this category yet.')),
      );
    }

    final q = _current;
    final questionText = q.q.resolve(lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.questionLabel(_index + 1, _questions.length)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_index + 1) / _questions.length,
                color: RukhsaColors.gold,
                backgroundColor: RukhsaColors.gold.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 16),
              if (q.needsVerification)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(t.needsVerificationBadge),
                    backgroundColor: Colors.amber.withValues(alpha: 0.2),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                questionText.text,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.35),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: q.options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final optionText = q.options[i].resolve(lang).text;
                    final isCorrect = i == q.answer;
                    final isSelected = i == _selected;

                    Color? bg;
                    Color border = Colors.black12;
                    if (_revealed) {
                      if (isCorrect) {
                        bg = RukhsaColors.success.withValues(alpha: 0.12);
                        border = RukhsaColors.success;
                      } else if (isSelected) {
                        bg = RukhsaColors.danger.withValues(alpha: 0.12);
                        border = RukhsaColors.danger;
                      }
                    }

                    return InkWell(
                      onTap: () => _select(i),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bg,
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(optionText, style: const TextStyle(fontSize: 15)),
                      ),
                    );
                  },
                ),
              ),
              if (_revealed) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: RukhsaColors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 20, color: RukhsaColors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          q.explanation.resolve(lang).text,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _next,
                  child: Text(
                    _index + 1 >= _questions.length ? t.finishQuiz : t.nextQuestion,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
