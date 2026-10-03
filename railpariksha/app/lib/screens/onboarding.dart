import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../logic/quiz_builder.dart';
import '../widgets/common.dart';
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

  // Placement diagnostic (step 2): built lazily once the exam is known, kept
  // around so stepping back/forward within onboarding doesn't rebuild it.
  QuizSpec? pSpec;
  int pIndex = 0;
  List<int?> pAnswers = const [];
  String? placementLevel;

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
                for (var i = 0; i < 4; i++)
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
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  // Default AnimatedSwitcher fade only -- language/exam/goal
                  // steps just faded/jumped despite this screen's hero
                  // gradient card being deliberately branded. A soft upward
                  // drift matches RpRoute's page-transition language instead.
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(step),
                    child: switch (step) {
                      0 => _language(p.lang),
                      1 => _exam(),
                      2 => _placement(),
                      _ => _goal(),
                    },
                  ),
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
                HapticFeedback.selectionClick();
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
              Icon(Icons.train, color: BrandColors.sunrise, size: 40),
              SizedBox(height: 12),
              Text('RailPariksha', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
              Text('Train to succeed · सफलता की पटरी पर', style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _heading('भाषा चुनें / Choose language', 'आप बाद में कभी भी बदल सकते हैं · Change anytime'),
        option('hi', 'हिंदी', 'Hindi'),
        option('en', 'English', 'अंग्रेज़ी'),
      ],
    );
  }

  Widget _exam() => Column(
        key: const ValueKey('exam'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(context.tr('आप किस परीक्षा की तैयारी कर रहे हैं?', 'Which exam are you preparing for?'),
              context.tr('सभी प्रश्न इसी परीक्षा के अनुसार दिखाए जाएंगे', 'Everything will be tailored to this exam')),
          Expanded(
            child: ExamPicker(
              selected: examId,
              onSelected: (id) {
                HapticFeedback.selectionClick();
                // Save the exam immediately so the placement diagnostic can
                // sample from the right subject pool.
                context.scope.progress.update((p) => p.examId = id);
                setState(() {
                  examId = id;
                  pSpec = null;
                  step = 2;
                });
              },
            ),
          ),
        ],
      );

  // ---------- Step 2: placement diagnostic ----------

  static const _labelsHi = ['अ', 'ब', 'क', 'ड'];
  static const _labelsEn = ['A', 'B', 'C', 'D'];

  void _buildPlacementSpec() {
    pSpec = AppScope.read(context).builder.placement();
    pIndex = 0;
    pAnswers = List.filled(pSpec!.questions.length, null);
  }

  void _skipPlacement() {
    HapticFeedback.selectionClick();
    setState(() {
      placementLevel = null;
      step = 3;
    });
  }

  void _finishPlacement() {
    final spec = pSpec!;
    final total = spec.questions.length;
    final correct = total == 0
        ? 0
        : [for (var i = 0; i < total; i++) pAnswers[i] == spec.questions[i].answer].where((c) => c).length;
    final pct = total == 0 ? 0.0 : correct / total;
    final level = pct > 0.7 ? 'advanced' : (pct >= 0.4 ? 'intermediate' : 'beginner');
    final suggested = switch (level) {
      'advanced' => 50,
      'intermediate' => 20,
      _ => 10,
    };
    setState(() {
      placementLevel = level;
      goal = suggested;
      step = 3;
    });
  }

  Widget _placement() {
    if (pSpec == null) _buildPlacementSpec();
    final spec = pSpec!;
    final total = spec.questions.length;

    if (total == 0) {
      // Not enough content for this exam yet to run a diagnostic -- don't block onboarding.
      return Column(
        key: const ValueKey('placement-empty'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: EmptyState(
              icon: Icons.quiz_outlined,
              text: context.tr(
                  'इस परीक्षा के लिए अभी स्तर जांच उपलब्ध नहीं है।', "Level check isn't available for this exam yet."),
              actionLabel: context.tr('आगे बढ़ें', 'Continue'),
              onAction: _skipPlacement,
            ),
          ),
        ],
      );
    }

    final lang = context.lang;
    final q = spec.questions[pIndex];
    final options = q.options(lang);
    final labels = lang == 'en' ? _labelsEn : _labelsHi;
    final answered = pAnswers[pIndex] != null;

    return Column(
      key: const ValueKey('placement'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _heading(
                context.tr('झटपट स्तर जांच', 'Quick level check'),
                context.tr('~$total प्रश्न · स्कोर नहीं जोड़ा जाएगा', '~$total questions · not scored'),
              ),
            ),
            TextButton(
              onPressed: _skipPlacement,
              child: Text(context.tr('छोड़ें', 'Skip')),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Row(children: [
                Text('${pIndex + 1} / $total', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 10),
              Text(q.text.of(lang), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4)),
              const SizedBox(height: 16),
              for (var i = 0; i < options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlacementOption(
                    label: labels[i],
                    text: options[i],
                    selected: pAnswers[pIndex] == i,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => pAnswers[pIndex] = i);
                    },
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton(
              onPressed: answered
                  ? () {
                      HapticFeedback.selectionClick();
                      if (pIndex + 1 < total) {
                        setState(() => pIndex++);
                      } else {
                        _finishPlacement();
                      }
                    }
                  : null,
              child: Text(pIndex + 1 < total
                  ? context.tr('अगला प्रश्न →', 'Next question →')
                  : context.tr('मेरा स्तर देखें', 'See my level')),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Step 3: daily goal ----------

  String _levelLabel(String level) => switch (level) {
        'advanced' => context.tr('उन्नत', 'Advanced'),
        'intermediate' => context.tr('मध्यम', 'Intermediate'),
        _ => context.tr('शुरुआती', 'Beginner'),
      };

  Widget _goal() {
    Widget option(int n, String hi, String en) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.local_fire_department,
                  color: goal == n ? BrandColors.saffron : Theme.of(context).hintColor, size: 32),
              title: Text(context.tr('$n प्रश्न / दिन', '$n questions / day'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(context.tr(hi, en)),
              trailing: goal == n ? const Icon(Icons.check_circle, color: BrandColors.saffron) : null,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => goal = n);
              },
            ),
          ),
        );
    return Column(
      key: const ValueKey('goal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(context.tr('रोज़ का लक्ष्य तय करें', 'Set your daily goal'),
            context.tr('रोज़ थोड़ा, पर बिना नागा — यही सफलता का राज़ है!', 'A little every day — that is the secret!')),
        if (placementLevel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: BrandColors.saffron.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.insights, color: BrandColors.saffron, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(
                        'आपका स्तर: ${_levelLabel(placementLevel!)} — उसी अनुसार लक्ष्य चुना गया है',
                        'Your level: ${_levelLabel(placementLevel!)} — goal pre-selected for you'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ),
        option(10, 'सफ़र में झटपट', 'Quick, on the go'),
        option(20, 'नियमित अभ्यास', 'Regular'),
        option(50, 'जी-जान से तैयारी', 'Serious aspirant'),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: BrandColors.saffron),
          icon: const Icon(Icons.rocket_launch),
          label: Text(context.tr('सफ़र शुरू करें!', "Let's go!")),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.scope.progress.update((p) {
              p.examId = examId;
              p.dailyGoal = goal;
              p.placementLevel = placementLevel;
              p.onboarded = true;
            });
          },
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => step = 2);
          },
          child: Text(context.tr('वापस', 'Back')),
        ),
      ],
    );
  }
}

class _PlacementOption extends StatelessWidget {
  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _PlacementOption({required this.label, required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = selected ? BrandColors.saffron : scheme.outlineVariant;
    final bg =
        selected ? BrandColors.saffron.withValues(alpha: 0.12) : Theme.of(context).cardTheme.color ?? scheme.surface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: selected ? 2 : 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: border.withValues(alpha: 0.18),
              child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.35))),
            if (selected) const Icon(Icons.radio_button_checked, color: BrandColors.saffron),
          ]),
        ),
      ),
    );
  }
}
