import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'home_screen.dart';
import 'quiz_screen.dart';

const double kPassThreshold = 0.7;

class ResultsScreen extends StatelessWidget {
  final String categoryId;
  final int correct;
  final int total;

  const ResultsScreen({
    super.key,
    required this.categoryId,
    required this.correct,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pct = total == 0 ? 0.0 : correct / total;
    final passed = pct >= kPassThreshold;

    return Scaffold(
      appBar: AppBar(title: Text(t.resultsTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                passed ? Icons.check_circle : Icons.error_outline,
                color: passed ? RukhsaColors.success : RukhsaColors.danger,
                size: 72,
              ),
              const SizedBox(height: 16),
              Text(t.yourScore, style: TextStyle(fontSize: 16, color: Theme.of(context).hintColor)),
              const SizedBox(height: 4),
              Text(
                '$correct / $total',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                passed ? t.passLabel : t.failLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: passed ? RukhsaColors.success : RukhsaColors.danger,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.passMarkNote,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => QuizScreen(categoryId: categoryId)),
                ),
                child: Text(t.retryQuiz),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                ),
                child: Text(t.backToHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
