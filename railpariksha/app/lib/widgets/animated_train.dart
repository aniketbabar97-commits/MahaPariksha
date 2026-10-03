import 'dart:math';

import 'package:flutter/material.dart';

/// The onboarding hero (first screen a new user ever sees) showed a
/// completely static train icon -- every other step transition in
/// onboarding already has real motion (AnimatedSwitcher fade+slide, the
/// AnimatedContainer progress bar), so this was the one flat spot. A small,
/// looping, native (no Lottie/image-asset dependency) animation: the train
/// icon bobs gently and three puffs of smoke drift up and fade, looping
/// continuously while this step is on screen.
class AnimatedTrainHero extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final double size;
  const AnimatedTrainHero({super.key, required this.icon, required this.iconColor, this.size = 40});

  @override
  State<AnimatedTrainHero> createState() => _AnimatedTrainHeroState();
}

class _AnimatedTrainHeroState extends State<AnimatedTrainHero> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size + 48,
      height: widget.size + 28,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final bob = sin(t * 2 * pi) * 3;
          return Stack(clipBehavior: Clip.none, alignment: Alignment.bottomLeft, children: [
            for (var i = 0; i < 3; i++) _puff(phase: i / 3, baseLeft: widget.size * 0.55),
            Transform.translate(
              offset: Offset(0, bob),
              child: Icon(widget.icon, color: widget.iconColor, size: widget.size),
            ),
          ]);
        },
      ),
    );
  }

  Widget _puff({required double phase, required double baseLeft}) {
    // Each puff runs its own 0..1 lifecycle offset by [phase] within the
    // controller's shared loop, so the three never move in lockstep.
    final local = (_c.value + phase) % 1.0;
    final opacity = (sin(local * pi)).clamp(0.0, 1.0) * 0.5;
    final rise = local * 26;
    final drift = local * 10;
    return Positioned(
      left: baseLeft + drift,
      bottom: widget.size * 0.45 + rise,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 7 + local * 6,
          height: 7 + local * 6,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
