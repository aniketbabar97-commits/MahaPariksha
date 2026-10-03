import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/progress.dart';

/// Shows a celebration for the notable events inside [r], if any.
Future<void> celebrate(BuildContext context, Reward r) async {
  final p = context.scope.progress;
  String? title;
  String? sub;
  IconData icon = Icons.emoji_events;
  if (r.levelUp) {
    title = context.tr('नया स्तर: ${p.level.hi}! 🚀', 'New level: ${p.level.en}! 🚀');
    sub = context.tr('आपकी ट्रेन अगले स्टेशन पर पहुँच गई!', 'You are flying higher!');
    icon = Icons.military_tech;
  } else if (r.streakMilestone != null) {
    title = context.tr('${r.streakMilestone} दिन की स्ट्रीक! 🔥', '${r.streakMilestone}-day streak! 🔥');
    sub = context.tr('निरंतरता ही असली ताकत है। ऐसे ही आगे बढ़ते रहें!', 'Consistency is your superpower. Keep going!');
    icon = Icons.local_fire_department;
  } else if (r.goalCompleted) {
    title = context.tr('आज का लक्ष्य पूरा! 🎯', 'Daily goal complete! 🎯');
    sub = context.tr('+50 XP बोनस। कल फिर मिलते हैं!', '+50 XP bonus. See you tomorrow!');
    icon = Icons.flag_circle;
  }
  if (title == null) return;
  HapticFeedback.heavyImpact();
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'celebrate',
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (ctx, _, _) => _CelebrationDialog(title: title!, sub: sub!, icon: icon),
    transitionBuilder: (ctx, a, _, child) =>
        ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: child),
  );
}

class _CelebrationDialog extends StatefulWidget {
  final String title;
  final String sub;
  final IconData icon;
  const _CelebrationDialog({required this.title, required this.sub, required this.icon});

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: c, builder: (_, _) => CustomPaint(painter: _Confetti(c.value))))),
      Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(gradient: BrandColors.heroGradient, borderRadius: BorderRadius.circular(28)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, color: BrandColors.sunrise, size: 72),
              const SizedBox(height: 12),
              Text(widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(widget.sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: BrandColors.saffron),
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('आगे बढ़ते रहें! 💪', 'Onwards! 💪')),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _Confetti extends CustomPainter {
  final double t;
  static final _rnd = Random(7);
  static final _pieces = List.generate(70, (_) => [_rnd.nextDouble(), _rnd.nextDouble(), _rnd.nextDouble(), _rnd.nextInt(4).toDouble()]);
  static const _colors = [BrandColors.saffron, BrandColors.sunrise, BrandColors.skyLight, BrandColors.correct];
  _Confetti(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _pieces) {
      final x = p[0] * size.width + sin((t + p[2]) * 8) * 20;
      final y = (p[1] * 0.3 - 0.3 + t * (1 + p[2])) * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 10 * p[2]);
      canvas.drawRect(const Rect.fromLTWH(-4, -7, 8, 14), Paint()..color = _colors[p[3].toInt()].withValues(alpha: 1 - t * 0.5));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => old.t != t;
}
