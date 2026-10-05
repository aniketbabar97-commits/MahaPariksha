// Text-contrast audit that names every offender (Flutter's own textContrastGuideline only says
// "found 2.68 for a font size of 12.5"). Renders the tree to pixels, then for every visible
// RenderParagraph compares the text colour with the dominant colour behind it (WCAG 2 ratio).
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

double _lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double _lum(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

Color _over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

/// Returns one line per text whose contrast is below WCAG AA (4.5, or 3.0 for large text).
Future<List<String>> contrastFindings(WidgetTester tester, GlobalKey boundaryKey, {String? savePng}) async {
  final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final size = boundary.size;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (savePng != null) {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(savePng).writeAsBytesSync(png!.buffer.asUint8List());
    }
    return (data!, image.width);
  });
  final (data, width) = bytes!;
  final px = data.buffer.asUint8List();
  Color at(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(px[i + 3], px[i], px[i + 1], px[i + 2]);
  }

  final out = <String>[];
  final seen = <String>{};
  // Text inside a disabled button is intentionally dimmed (WCAG exempts inactive controls).
  bool inDisabledButton(RenderParagraph ro) {
    final creator = ro.debugCreator;
    if (creator is! DebugCreator) return false;
    var disabled = false;
    creator.element.visitAncestorElements((e) {
      final w = e.widget;
      if (w is ButtonStyleButton) {
        disabled = !w.enabled;
        return false;
      }
      return true;
    });
    return disabled;
  }

  // Text that has scrolled underneath an opaque bar (e.g. the last option of a long question behind the
  // quiz's bottom bar) is not on screen, even though its box is inside the viewport. A hit test at its
  // centre tells: if the paragraph is not on the hit path, something else is painted over it.
  bool coveredByAnotherLayer(RenderParagraph ro) {
    final centre = ro.localToGlobal(ro.size.center(Offset.zero));
    final result = HitTestResult();
    tester.binding.hitTestInView(result, centre, tester.view.viewId);
    return result.path.isNotEmpty && !result.path.any((e) => identical(e.target, ro));
  }

  void visit(RenderObject ro) {
    if (ro is RenderParagraph && ro.attached && ro.hasSize && !inDisabledButton(ro) && !coveredByAnotherLayer(ro)) {
      var text = ro.text.toPlainText().replaceAll(RegExp(r'\s+'), ' ').trim();
      // Icon-font glyphs (private-use code points) are non-text graphics: 3:1 and labelled ICON.
      final isIcon = text.isNotEmpty && text.runes.every((r) => r >= 0xE000 && r <= 0xF8FF);
      if (isIcon) text = 'ICON';
      final style = ro.text.style;
      if (text.isNotEmpty && style?.color != null) {
        final topLeft = ro.localToGlobal(Offset.zero, ancestor: boundary);
        final rect = (topLeft & ro.size).intersect(Offset.zero & size);
        // Text scrolled out of view / clipped away is not a finding.
        if (rect.width > 4 && rect.height > 4) {
          // Dominant colour in the text's box = what it sits on.
          final hist = <int, int>{};
          final step = math.max(1, (rect.width * rect.height / 400).floor() ~/ 1);
          var n = 0;
          for (var y = rect.top.floor(); y < rect.bottom.ceil(); y += 1) {
            for (var x = rect.left.floor(); x < rect.right.ceil(); x += 1) {
              if (((x + y * 7) % math.max(1, math.sqrt(step).floor())) != 0) continue;
              final c = at(x.clamp(0, width - 1), y.clamp(0, size.height.toInt() - 1));
              // quantise to 4 bits/channel so anti-aliasing noise doesn't split a flat fill
              final k = ((c.r * 255).round() >> 4 << 8) | ((c.g * 255).round() >> 4 << 4) | ((c.b * 255).round() >> 4);
              hist[k] = (hist[k] ?? 0) + 1;
              n++;
            }
          }
          if (n > 0) {
            final top = hist.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
            // Average the real pixels that fall in the winning bucket.
            double r = 0, g = 0, b = 0;
            var m = 0;
            for (var y = rect.top.floor(); y < rect.bottom.ceil(); y++) {
              for (var x = rect.left.floor(); x < rect.right.ceil(); x++) {
                final c = at(x.clamp(0, width - 1), y.clamp(0, size.height.toInt() - 1));
                final k = ((c.r * 255).round() >> 4 << 8) | ((c.g * 255).round() >> 4 << 4) | ((c.b * 255).round() >> 4);
                if (k == top) {
                  r += c.r;
                  g += c.g;
                  b += c.b;
                  m++;
                }
              }
            }
            final bg = Color.from(alpha: 1, red: r / m, green: g / m, blue: b / m);
            final fg = _over(style!.color!, bg);
            final fontSize = style.fontSize ?? 14;
            final bold = (style.fontWeight?.value ?? 400) >= 700;
            final large = fontSize >= 18 || (fontSize >= 14 && bold);
            final need = (large || isIcon) ? 3.0 : 4.5;
            final ratio = contrast(fg, bg);
            if (ratio < need) {
              final line = '"${text.length > 40 ? '${text.substring(0, 40)}…' : text}" '
                  '${fontSize.toStringAsFixed(1)}px${bold ? ' bold' : ''} fg ${_hex(fg)} on ${_hex(bg)} = ${ratio.toStringAsFixed(2)} (need $need)';
              if (seen.add(line)) out.add(line);
            }
          }
        }
      }
    }
    ro.visitChildren(visit);
  }

  visit(boundary);
  return out;
}
