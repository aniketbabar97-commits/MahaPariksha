import 'dart:math';

import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/progress.dart';

/// Shows a celebration for the notable events inside [r], if any.
Future<void> celebrate(BuildContext context, Reward r) async {
  final p = context.scope.progress;
  String? title;
  String? sub;
  String? shareText;
  IconData icon = Icons.emoji_events;
  if (r.levelUp) {
    title = context.tr('नया स्तर: ${p.level.hi}! 🚀', 'New level: ${p.level.en}! 🚀');
    sub = context.tr('आपकी ट्रेन अगले स्टेशन पर पहुँच गई!', 'You are flying higher!');
    icon = Icons.military_tech;
    // Level-up and streak milestones are this app's highest-arousal, most
    // brag-worthy moments (confetti + a hard-won train-rank jump) -- the
    // only two celebration types worth a share prompt; a daily goal is too
    // routine to ask the user to post about every single day.
    shareText = context.tr(
        'मैं RailPariksha पर ${p.level.hi} स्तर पर पहुंच गया! 🚀 आप भी आज से शुरू करें: $kPlayUrl',
        'I just reached ${p.level.en} level on RailPariksha! 🚀 Start your own prep today: $kPlayUrl');
  } else if (r.streakMilestone != null) {
    title = context.tr('${r.streakMilestone} दिन की स्ट्रीक! 🔥', '${r.streakMilestone}-day streak! 🔥');
    sub = context.tr('निरंतरता ही असली ताकत है। ऐसे ही आगे बढ़ते रहें!', 'Consistency is your superpower. Keep going!');
    icon = Icons.local_fire_department;
    shareText = context.tr(
        'मेरी RailPariksha पर ${r.streakMilestone} दिन की स्ट्रीक है! 🔥 आप भी शुरू करें: $kPlayUrl',
        "I'm on a ${r.streakMilestone}-day streak on RailPariksha! 🔥 Start yours: $kPlayUrl");
  } else if (r.freezeSaved) {
    // A freeze token silently bridging a missed day used to be invisible --
    // the streak just kept going with no sign anything had happened, so the
    // token's whole value (and the fact the user has one fewer left) went
    // unnoticed. Not share-worthy like a level-up or milestone, just worth
    // surfacing.
    title = context.tr('स्ट्रीक बच गई! ❄️', 'Streak saved! ❄️');
    sub = context.tr(
        'आपके फ़्रीज़ टोकन ने कल का दिन छूटने पर भी आपकी स्ट्रीक बचा ली।', 'A freeze token covered yesterday — your streak lives on.');
    icon = Icons.ac_unit;
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
    pageBuilder: (ctx, _, _) => _CelebrationDialog(title: title!, sub: sub!, icon: icon, shareText: shareText),
    transitionBuilder: (ctx, a, _, child) =>
        ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: child),
  );
  // Ask for a Play rating right after a level-up or a 7-day-plus streak lands: the student has
  // just celebrated, nothing was interrupted, and no ad is on screen. Throttled in Progress.
  if ((r.levelUp || (r.streakMilestone ?? 0) >= 7) && context.mounted && p.shouldAskForReviewAfterMilestone()) {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        p.markReviewAsked();
        await review.requestReview();
      }
    } catch (_) {
      // No Play services: a rating ask is optional.
    }
  }
}

class _CelebrationDialog extends StatefulWidget {
  final String title;
  final String sub;
  final IconData icon;
  final String? shareText;
  const _CelebrationDialog({required this.title, required this.sub, required this.icon, this.shareText});

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
    final reduceMotion = BrandColors.reduceMotion(context);
    return Stack(children: [
      // "Remove animations" users get the dialog with no confetti burst --
      // a rapid shower of spinning/falling pieces is a genuine motion-
      // sickness trigger for some, not just unwanted decoration.
      if (!reduceMotion)
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
              Text(widget.sub, textAlign: TextAlign.center, style: const TextStyle(color: BrandColors.onGradientMuted, fontSize: 16)),
              const SizedBox(height: 20),
              if (widget.shareText != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        minimumSize: const Size(64, 48)),
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(context.tr('दोस्तों को बताएं', 'Share with friends')),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      SharePlus.instance.share(ShareParams(text: widget.shareText!));
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: BrandColors.saffron, foregroundColor: BrandColors.onSaffron),
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
