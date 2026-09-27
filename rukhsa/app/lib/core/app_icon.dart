import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'theme.dart';

/// Vector rendition of the Rukhsa brand mark: a blue field, a gold steering
/// wheel containing a small car icon over a road, with the wordmark under
/// it. Drawn entirely with [CustomPainter] so no binary image asset is
/// required; this same painter is what `tools/render_app_icon.dart` (a
/// one-off script, see its header) would drive to rasterize a launcher icon
/// once a Flutter SDK/`dart run` is available in the build environment.
class RukhsaLogoMark extends StatelessWidget {
  final double size;
  final bool roundedSquareBackground;
  const RukhsaLogoMark({super.key, this.size = 120, this.roundedSquareBackground = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _RukhsaLogoPainter(roundedSquareBackground: roundedSquareBackground),
    );
  }
}

class _RukhsaLogoPainter extends CustomPainter {
  final bool roundedSquareBackground;
  _RukhsaLogoPainter({required this.roundedSquareBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2 - h * 0.03);

    // 1. Background field.
    final bgPaint = Paint()
      ..shader = RukhsaColors.heroGradient.createShader(Rect.fromLTWH(0, 0, w, h));
    if (roundedSquareBackground) {
      final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(w * 0.22));
      canvas.drawRRect(rrect, bgPaint);
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);
    }

    // 2. Road: a light-grey trapezoid with a dashed centre line, receding
    // toward the wheel hub, sitting behind the wheel.
    final roadPaint = Paint()..color = Colors.white.withValues(alpha: 0.14);
    final roadPath = Path()
      ..moveTo(w * 0.30, h * 0.92)
      ..lineTo(w * 0.70, h * 0.92)
      ..lineTo(w * 0.56, h * 0.58)
      ..lineTo(w * 0.44, h * 0.58)
      ..close();
    canvas.drawPath(roadPath, roadPaint);

    final dashPaint = Paint()
      ..color = RukhsaColors.goldLight.withValues(alpha: 0.9)
      ..strokeWidth = w * 0.014
      ..strokeCap = StrokeCap.round;
    for (final t in [0.63, 0.73, 0.83]) {
      canvas.drawLine(Offset(w * 0.5, h * t), Offset(w * 0.5, h * (t + 0.05)), dashPaint);
    }

    // 3. Gold steering wheel, outer ring + 3 spokes + hub.
    final wheelRadius = w * 0.30;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.052
      ..shader = RukhsaColors.goldGradient.createShader(
        Rect.fromCircle(center: center, radius: wheelRadius),
      );
    canvas.drawCircle(center, wheelRadius, ringPaint);

    final spokePaint = Paint()
      ..color = RukhsaColors.gold
      ..strokeWidth = w * 0.034
      ..strokeCap = StrokeCap.round;
    final hubRadius = w * 0.085;
    for (int i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / 3);
      final outer = Offset(
        center.dx + (wheelRadius - w * 0.02) * math.cos(angle),
        center.dy + (wheelRadius - w * 0.02) * math.sin(angle),
      );
      final inner = Offset(
        center.dx + hubRadius * math.cos(angle),
        center.dy + hubRadius * math.sin(angle),
      );
      canvas.drawLine(inner, outer, spokePaint);
    }
    canvas.drawCircle(center, hubRadius, Paint()..color = RukhsaColors.blueDark);
    canvas.drawCircle(center, hubRadius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..color = RukhsaColors.goldLight);

    // 4. Small car glyph sitting on the hub (simple silhouette).
    final carPaint = Paint()..color = RukhsaColors.goldLight;
    final carW = hubRadius * 1.5;
    final carH = hubRadius * 0.75;
    final carRect = Rect.fromCenter(center: center, width: carW, height: carH * 0.62);
    final body = RRect.fromRectAndRadius(carRect, Radius.circular(carH * 0.2));
    canvas.drawRRect(body, carPaint);
    final roofRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - carH * 0.28),
      width: carW * 0.55,
      height: carH * 0.4,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(roofRect, Radius.circular(carH * 0.12)), carPaint);
  }

  @override
  bool shouldRepaint(covariant _RukhsaLogoPainter oldDelegate) => false;
}

/// Full lockup: logo mark + "RUKHSA" wordmark + "UAE DRIVING TEST" tagline,
/// used on the splash/language-picker screen and about section.
class RukhsaWordmarkLockup extends StatelessWidget {
  final double markSize;
  const RukhsaWordmarkLockup({super.key, this.markSize = 96});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RukhsaLogoMark(size: markSize),
        const SizedBox(height: 14),
        const Text(
          'RUKHSA',
          style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 5),
        ),
        const SizedBox(height: 2),
        Text(
          'UAE DRIVING TEST',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 3),
        ),
      ],
    );
  }
}
