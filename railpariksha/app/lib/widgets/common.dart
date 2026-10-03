import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import 'exam_picker.dart';

class GoalRing extends StatelessWidget {
  final double progress;
  final double size;
  final Widget child;
  const GoalRing({super.key, required this.progress, this.size = 120, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  _RingPainter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, 2 * pi, false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    if (v <= 0) return;
    canvas.drawArc(
        r,
        -pi / 2,
        2 * pi * v,
        false,
        Paint()
          ..shader = const SweepGradient(
            colors: [BrandColors.sunrise, BrandColors.saffron, BrandColors.sunrise],
            transform: GradientRotation(-pi / 2),
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v;
}

/// Streak shown as a bird rising through "sky levels". Pops in with a little
/// bounce whenever the streak count changes, so gains feel rewarding.
class StreakWings extends StatelessWidget {
  final int streak;
  const StreakWings({super.key, required this.streak});

  static int skyLevel(int s) => s >= 100 ? 5 : s >= 50 ? 4 : s >= 21 ? 3 : s >= 7 ? 2 : s >= 3 ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    final lvl = skyLevel(streak);
    return Semantics(
      label: context.tr('स्ट्रीक $streak दिन', 'Streak: $streak days'),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(streak),
        tween: Tween(begin: streak > 0 ? 0.6 : 1, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs + 2),
          decoration: BoxDecoration(
            gradient: streak > 0 ? BrandColors.fireGradient : null,
            color: streak > 0 ? null : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Transform.translate(
              offset: Offset(0, -lvl.toDouble()),
              child: Icon(lvl >= 3 ? Icons.flight : Icons.local_fire_department, color: Colors.white, size: 20),
            ),
            const SizedBox(width: Spacing.xs),
            Text('$streak', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ]),
        ),
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  const ActionCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // Disabled (onTap == null, e.g. Mistake Book with no mistakes yet) looked
    // identical to an active card save for the subtitle text -- dim the icon
    // chip and title so the inactive state reads at a glance, not just on
    // careful reading of the subtitle copy.
    final disabled = onTap == null;
    final hint = Theme.of(context).hintColor;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: (disabled ? hint : color).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: disabled ? hint : color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16, color: disabled ? hint : null)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: hint, fontSize: 13)),
              ]),
            ),
            trailing ?? Icon(Icons.chevron_right, color: hint),
          ]),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );
}

/// A friendly bilingual placeholder for empty lists, missing data, or errors.
/// [actionLabel]/[onAction] optionally offer a way forward instead of a dead end.
/// A layered sunrise-ring illustration (matching the brand mark) behind the
/// icon instead of a bare Material icon, so every empty/done state still
/// feels designed rather than like an unfinished screen.
class EmptyState extends StatefulWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.text, this.actionLabel, this.onAction});

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xxl + 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(
              scale: CurvedAnimation(parent: c, curve: Curves.elasticOut),
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: BrandColors.saffron.withValues(alpha: 0.08)),
                  ),
                  Container(
                    width: 88,
                    height: 88,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: BrandColors.saffron.withValues(alpha: 0.14)),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(gradient: BrandColors.fireGradient, shape: BoxShape.circle),
                    child: Icon(widget.icon, size: 30, color: Colors.white),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(widget.text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (widget.actionLabel != null && widget.onAction != null) ...[
              const SizedBox(height: Spacing.lg),
              FilledButton(onPressed: widget.onAction, child: Text(widget.actionLabel!)),
            ],
          ]),
        ),
      );
}

/// Shown in place of any exam-scoped screen when no exam has been selected
/// yet (e.g. onboarding was skipped or progress was reset), instead of a
/// blank white screen.
class NoExamState extends StatelessWidget {
  const NoExamState({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.train_outlined,
            text: context.tr('पहले अपनी परीक्षा चुनें ताकि सही प्रश्न दिख सकें।',
                'Pick your exam first so we can show the right questions.'),
            actionLabel: context.tr('परीक्षा चुनें', 'Choose exam'),
            onAction: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (ctx) => SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                  child: ExamPicker(
                    selected: ctx.scope.progress.examId,
                    onSelected: (id) {
                      ctx.scope.progress.update((p) => p.examId = id);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
