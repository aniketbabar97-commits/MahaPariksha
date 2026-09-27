import 'dart:async';
import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/design_system.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../logic/mock_exam.dart';
import 'mock_exam_results_screen.dart';

/// Timed mock exam mode replicating the real RTA format: 35 questions,
/// 30-minute countdown, auto-submits on timeout.
class MockExamScreen extends StatefulWidget {
  const MockExamScreen({super.key});

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  late List<Question> _questions;
  final Map<String, int> _answers = {};
  int _index = 0;
  late Timer _timer;
  Duration _remaining = kMockExamDuration;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final scope = AppScopeProvider.of(context);
    _questions = buildMockExam(scope.filteredQuestions);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _submitted) return;
    setState(() {
      _remaining -= const Duration(seconds: 1);
      if (_remaining <= Duration.zero) {
        _remaining = Duration.zero;
        _submit(timedOut: true);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _select(int optionIndex) {
    setState(() => _answers[_questions[_index].id] = optionIndex);
  }

  void _submit({bool timedOut = false}) {
    if (_submitted) return;
    _submitted = true;
    _timer.cancel();
    final results = _questions.map((q) => MockExamAnswer(q, _answers[q.id])).toList();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MockExamResultsScreen(answers: results, timedOut: timedOut)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mock Exam')),
        body: const AppEmptyState(icon: Icons.warning_amber_outlined, text: 'Not enough questions available to build a mock exam yet.'),
      );
    }
    final q = _questions[_index];
    final lang = AppScopeProvider.of(context).lang;
    final urgent = _remaining.inSeconds <= 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmExit(context);
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Question ${_index + 1} / ${_questions.length}'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: urgent ? RukhsaColors.dangerDark : Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_remaining),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: urgent ? RukhsaColors.dangerDark : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: (_index + 1) / _questions.length,
                  color: RukhsaColors.gold,
                  backgroundColor: RukhsaColors.gold.withValues(alpha: 0.15),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(q.q.resolve(lang).text, style: AppType.h1),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: ListView.separated(
                    itemCount: q.options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final selected = _answers[q.id] == i;
                      return InkWell(
                        onTap: () => _select(i),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: selected ? RukhsaColors.gold.withValues(alpha: 0.16) : null,
                            border: Border.all(color: selected ? RukhsaColors.gold : Colors.black12),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Text(q.options[i].resolve(lang).text, style: AppType.body),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _index == 0 ? null : () => setState(() => _index -= 1),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_index + 1 >= _questions.length) {
                            _submit();
                          } else {
                            setState(() => _index += 1);
                          }
                        },
                        child: Text(_index + 1 >= _questions.length ? 'Submit exam' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmExit(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave mock exam?'),
          content: const Text('Your progress on this timed exam will be lost.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
          ],
        ),
      );

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
