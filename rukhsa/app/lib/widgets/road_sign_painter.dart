import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/road_signs.dart';

Color _colorFor(String name) => switch (name) {
      'red' => RukhsaColors.signRed,
      'blue' => RukhsaColors.signBlue,
      'yellow' => RukhsaColors.signYellow,
      'white' => RukhsaColors.signWhite,
      'green' => RukhsaColors.signGreen,
      _ => RukhsaColors.signBlack,
    };

/// Draws a single road sign to real UAE/MUTCD-style shape + color
/// conventions: red triangles for warnings, blue circles for mandatory
/// instructions, red-bordered white circles for prohibitions, blue/green
/// rectangles for informatory guides, and the two unique shapes (octagon for
/// STOP, inverted triangle for GIVE WAY).
class RoadSignIcon extends StatelessWidget {
  final RoadSign sign;
  final double size;
  const RoadSignIcon({super.key, required this.sign, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SignPainter(sign),
    );
  }
}

class _SignPainter extends CustomPainter {
  final RoadSign sign;
  _SignPainter(this.sign);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08;

    switch (sign.shape) {
      case RoadSignShape.octagon:
        // STOP: red octagon, white border, white text bar suggested by a
        // horizontal band (kept abstract — real signs carry Arabic/English
        // text, out of scope for a shape-accurate vector).
        final path = _octagonPath(w, h);
        canvas.drawPath(path, fill..color = RukhsaColors.signRed);
        canvas.drawPath(path, stroke..color = Colors.white);
        _centerBar(canvas, w, h, Colors.white);
        break;

      case RoadSignShape.invertedTriangle:
        // GIVE WAY: white inverted triangle, thick red border.
        final path = _trianglePath(w, h, pointDown: true, inset: w * 0.06);
        canvas.drawPath(path, fill..color = Colors.white);
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.11
          ..color = RukhsaColors.signRed);
        break;

      case RoadSignShape.triangle:
        // WARNING: yellow (or white) triangle, red border, black glyph dot.
        final bg = _colorFor(sign.primaryColor);
        final path = _trianglePath(w, h, pointDown: false, inset: w * 0.05);
        canvas.drawPath(path, fill..color = bg);
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.07
          ..color = RukhsaColors.signRed);
        canvas.drawCircle(Offset(w / 2, h * 0.62), w * 0.09, Paint()..color = RukhsaColors.signBlack);
        break;

      case RoadSignShape.circle:
        final isProhibitory = sign.category == 'prohibitory';
        final bg = isProhibitory ? Colors.white : _colorFor(sign.primaryColor);
        final radius = w * 0.42;
        canvas.drawCircle(Offset(w / 2, h / 2), radius, fill..color = bg);
        if (isProhibitory || sign.id == 'no_entry') {
          canvas.drawCircle(
            Offset(w / 2, h / 2),
            radius - w * 0.045,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.09
              ..color = RukhsaColors.signRed,
          );
        }
        _glyphFor(canvas, sign, w, h);
        break;

      case RoadSignShape.rectangle:
        final bg = _colorFor(sign.primaryColor);
        final rect = Rect.fromLTWH(w * 0.08, h * 0.2, w * 0.84, h * 0.6);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(w * 0.04)), fill..color = bg);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(w * 0.04)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.02
            ..color = Colors.white,
        );
        _glyphFor(canvas, sign, w, h);
        break;

      case RoadSignShape.diamond:
        final path = Path()
          ..moveTo(w / 2, h * 0.08)
          ..lineTo(w * 0.92, h / 2)
          ..lineTo(w / 2, h * 0.92)
          ..lineTo(w * 0.08, h / 2)
          ..close();
        canvas.drawPath(path, fill..color = RukhsaColors.signYellow);
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.05
          ..color = RukhsaColors.signBlack);
        break;
    }
  }

  void _glyphFor(Canvas canvas, RoadSign sign, double w, double h) {
    final glyph = Paint()..color = sign.category == 'prohibitory' ? RukhsaColors.signBlack : Colors.white;
    final center = Offset(w / 2, h / 2);
    // A minimal representative glyph per sign id — arrows/bars/symbols drawn
    // simply rather than photorealistic pictograms.
    switch (sign.id) {
      case 'no_entry':
        canvas.drawRect(Rect.fromCenter(center: center, width: w * 0.5, height: h * 0.11), Paint()..color = Colors.white);
        break;
      case 'no_u_turn':
      case 'no_overtaking':
      case 'no_horn':
      case 'no_parking':
        canvas.drawLine(
          Offset(w * 0.28, h * 0.28),
          Offset(w * 0.72, h * 0.72),
          Paint()
            ..color = RukhsaColors.signRed
            ..strokeWidth = w * 0.07
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(center, w * 0.16, glyph);
        break;
      case 'max_speed_limit':
        _numberBadge(canvas, center, w, '80');
        break;
      case 'minimum_speed':
        _numberBadge(canvas, center, w, '60', color: Colors.white);
        break;
      case 'straight_only':
      case 'turn_right_only':
      case 'roundabout_ahead_mandatory':
        _arrow(canvas, center, w, right: sign.id == 'turn_right_only');
        break;
      case 'cycle_lane':
        canvas.drawCircle(Offset(center.dx - w * 0.12, center.dy + h * 0.1), w * 0.07, glyph);
        canvas.drawCircle(Offset(center.dx + w * 0.12, center.dy + h * 0.1), w * 0.07, glyph);
        break;
      case 'hospital':
        canvas.drawRect(Rect.fromCenter(center: center, width: w * 0.09, height: h * 0.34), glyph);
        canvas.drawRect(Rect.fromCenter(center: center, width: w * 0.34, height: h * 0.09), glyph);
        break;
      case 'parking_info':
        canvas.drawCircle(center, w * 0.18, glyph);
        break;
      case 'fuel_station':
        canvas.drawRect(Rect.fromCenter(center: center, width: w * 0.22, height: h * 0.34), glyph);
        break;
      case 'highway_exit':
        _arrow(canvas, center, w, right: true);
        break;
      default:
        canvas.drawCircle(center, w * 0.12, glyph);
    }
  }

  void _numberBadge(Canvas canvas, Offset center, double w, String n, {Color color = RukhsaColors.signBlack}) {
    final tp = TextPainter(
      text: TextSpan(text: n, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: w * 0.22)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _arrow(Canvas canvas, Offset center, double w, {bool right = false}) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;
    if (right) {
      canvas.drawLine(Offset(center.dx - w * 0.14, center.dy), Offset(center.dx + w * 0.14, center.dy), p);
      canvas.drawLine(Offset(center.dx + w * 0.14, center.dy), Offset(center.dx + w * 0.02, center.dy - w * 0.1), p);
      canvas.drawLine(Offset(center.dx + w * 0.14, center.dy), Offset(center.dx + w * 0.02, center.dy + w * 0.1), p);
    } else {
      canvas.drawLine(Offset(center.dx, center.dy + w * 0.16), Offset(center.dx, center.dy - w * 0.16), p);
      canvas.drawLine(Offset(center.dx, center.dy - w * 0.16), Offset(center.dx - w * 0.1, center.dy - w * 0.04), p);
      canvas.drawLine(Offset(center.dx, center.dy - w * 0.16), Offset(center.dx + w * 0.1, center.dy - w * 0.04), p);
    }
  }

  void _centerBar(Canvas canvas, double w, double h, Color color) {
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.5, height: h * 0.08), Paint()..color = color);
  }

  Path _octagonPath(double w, double h) {
    final path = Path();
    final cx = w / 2, cy = h / 2, r = w * 0.46;
    for (int i = 0; i < 8; i++) {
      final angle = math.pi / 8 + i * (math.pi / 4);
      final pt = Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  Path _trianglePath(double w, double h, {required bool pointDown, required double inset}) {
    final path = Path();
    if (pointDown) {
      path.moveTo(inset, inset);
      path.lineTo(w - inset, inset);
      path.lineTo(w / 2, h - inset);
    } else {
      path.moveTo(w / 2, inset);
      path.lineTo(w - inset, h - inset);
      path.lineTo(inset, h - inset);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SignPainter oldDelegate) => oldDelegate.sign.id != sign.id;
}
