import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../widgets/exam_picker.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  String? examId;
  int goal = 20;

  @override
  Widget build(BuildContext context) {
    final p = context.scope.progress;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= step ? BrandColors.saffron : Colors.grey.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (step) {
                    0 => _language(p.lang),
                    1 => _exam(),
                    _ => _goal(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(sub, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: 20),
        ],
      );

  Widget _language(String current) {
    Widget option(String code, String label, String sub) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              subtitle: Text(sub),
              trailing: Icon(current == code ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: BrandColors.saffron),
              onTap: () {
                context.scope.progress.update((p) => p.lang = code);
                setState(() => step = 1);
              },
            ),
          ),
        );
    return Column(
      key: const ValueKey('lang'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: BrandColors.heroGradient, borderRadius: BorderRadius.circular(24)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flight_takeoff, color: BrandColors.sunrise, size: 40),
              SizedBox(height: 12),
              Text('भरारी', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              Text('उंच भरारी घ्या · Fly high', style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _heading('भाषा निवडा / Choose language', 'तुम्ही नंतर कधीही बदलू शकता · Change anytime'),
        option('mr', 'मराठी', 'Marathi'),
        option('en', 'English', 'इंग्रजी'),
      ],
    );
  }

  Widget _exam() => Column(
        key: const ValueKey('exam'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(context.tr('तुमची परीक्षा कोणती?', 'Which exam are you preparing for?'),
              context.tr('सर्व प्रश्न या परीक्षेनुसार दिसतील', 'Everything will be tailored to this exam')),
          Expanded(
            child: ExamPicker(
              selected: examId,
              onSelected: (id) => setState(() {
                examId = id;
                step = 2;
              }),
            ),
          ),
        ],
      );

  Widget _goal() {
    Widget option(int n, String mr, String en) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.local_fire_department,
                  color: goal == n ? BrandColors.saffron : Theme.of(context).hintColor, size: 32),
              title: Text(context.tr('$n प्रश्न / दिवस', '$n questions / day'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(context.tr(mr, en)),
              trailing: goal == n ? const Icon(Icons.check_circle, color: BrandColors.saffron) : null,
              onTap: () => setState(() => goal = n),
            ),
          ),
        );
    return Column(
      key: const ValueKey('goal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(context.tr('रोजचे लक्ष्य ठरवा', 'Set your daily goal'),
            context.tr('रोज थोडं, पण न चुकता — हेच यशाचं गुपित!', 'A little every day — that is the secret!')),
        option(10, 'प्रवासात झटपट', 'Quick, on the go'),
        option(20, 'नियमित अभ्यास', 'Regular'),
        option(50, 'जिद्दीने तयारी', 'Serious aspirant'),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: BrandColors.saffron),
          icon: const Icon(Icons.rocket_launch),
          label: Text(context.tr('भरारी घ्या!', "Let's fly!")),
          onPressed: () => context.scope.progress.update((p) {
            p.examId = examId;
            p.dailyGoal = goal;
            p.onboarded = true;
          }),
        ),
        TextButton(onPressed: () => setState(() => step = 1), child: Text(context.tr('मागे', 'Back'))),
      ],
    );
  }
}
