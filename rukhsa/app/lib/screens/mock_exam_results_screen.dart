import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/design_system.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../logic/mock_exam.dart';
import 'home_screen.dart';
import 'mock_exam_screen.dart';

/// Mock-exam results: overall pass/fail against the real 23/35 (65%) RTA
/// pass mark, plus a category-wise right/wrong breakdown (weakest first) so
/// the learner knows exactly what to restudy — the "weak area" feature.
class MockExamResultsScreen extends StatelessWidget {
  final List<MockExamAnswer> answers;
  final bool timedOut;
  const MockExamResultsScreen({super.key, required this.answers, this.timedOut = false});

  @override
  Widget build(BuildContext context) {
    final scope = AppScopeProvider.of(context);
    final bundle = scope.bundle!;
    final lang = scope.lang;
    final correct = answers.where((a) => a.isCorrect).length;
    final total = answers.length;
    final passed = correct >= kMockExamPassCount;
    final breakdown = summarizeByCategory(answers);

    return Scaffold(
      appBar: AppBar(title: const Text('Mock Exam Results')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (timedOut)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppBadge(label: 'Time ran out — auto-submitted', color: RukhsaColors.danger.withValues(alpha: 0.15), foreground: RukhsaColors.danger),
              ),
            Center(
              child: ProgressRing(
                value: total == 0 ? 0 : correct / total,
                size: 140,
                color: passed ? RukhsaColors.success : RukhsaColors.danger,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$correct/$total', style: AppType.display.copyWith(fontSize: 26)),
                    Text(passed ? 'PASS' : 'FAIL',
                        style: TextStyle(fontWeight: FontWeight.w900, color: passed ? RukhsaColors.success : RukhsaColors.danger)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                'Pass mark: $kMockExamPassCount / $kMockExamQuestionCount (65%) — the real RTA computer test threshold.',
                textAlign: TextAlign.center,
                style: AppType.caption.copyWith(color: Theme.of(context).hintColor, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Category breakdown', style: AppType.h2),
            const SizedBox(height: AppSpacing.sm),
            for (final b in breakdown) _CategoryRow(breakdown: b, bundle: bundle, lang: lang),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MockExamScreen()),
              ),
              child: const Text('Retake mock exam'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              ),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryBreakdown breakdown;
  final ContentBundle bundle;
  final String lang;
  const _CategoryRow({required this.breakdown, required this.bundle, required this.lang});

  @override
  Widget build(BuildContext context) {
    final matches = bundle.categories.where((c) => c.id == breakdown.category);
    final name = matches.isEmpty ? breakdown.category : matches.first.name(lang);
    final weak = breakdown.ratio < 0.6;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppType.body.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: breakdown.ratio,
                      minHeight: 6,
                      backgroundColor: Colors.black12,
                      color: weak ? RukhsaColors.danger : RukhsaColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('${breakdown.correct}/${breakdown.total}', style: AppType.caption),
            if (weak) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.priority_high, size: 16, color: RukhsaColors.danger)),
          ],
        ),
      ),
    );
  }
}
