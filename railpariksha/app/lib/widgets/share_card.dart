import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme.dart';

/// Branded, shareable result card -- rendered off-screen and captured as a
/// PNG so a score lands in WhatsApp/etc. as an actual image (with the app's
/// colors/branding visible in the chat thread) instead of a plain-text
/// message that's indistinguishable from anything else in the conversation.
class ScoreShareCard extends StatelessWidget {
  final String headline;
  final String scoreText;
  final String scoreSub;
  final String footer;
  final IconData icon;

  const ScoreShareCard({
    super.key,
    required this.headline,
    required this.scoreText,
    required this.scoreSub,
    required this.footer,
    this.icon = Icons.train,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 40),
      decoration: const BoxDecoration(gradient: BrandColors.heroGradient),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: const Icon(Icons.train, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 10),
          const Text('RailPariksha', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 32),
        Text(headline,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: BrandColors.sunrise, size: 30),
            const SizedBox(height: 8),
            Text(scoreText, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(scoreSub, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 32),
        Text(footer,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(kPlayUrl,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
      ]),
    );
  }
}

/// Renders [card] off-screen, captures it as a PNG, writes it to a temp
/// file, and opens the native share sheet with that image plus [text] as
/// the accompanying caption. Falls back to text-only sharing if image
/// rendering fails for any reason (e.g. low memory) so a share action never
/// just silently does nothing.
Future<void> shareScoreCard(BuildContext context, {required ScoreShareCard card, required String text}) async {
  try {
    final repaintKey = GlobalKey();
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -3000,
        top: 0,
        child: RepaintBoundary(key: repaintKey, child: Material(color: Colors.transparent, child: card)),
      ),
    );
    final overlayState = Overlay.of(context, rootOverlay: true);
    overlayState.insert(overlay);
    // One extra frame so layout/paint actually completes before capture --
    // inserting and capturing in the same frame reliably grabs a blank image.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('card not laid out');
    final image = await boundary.toImage(pixelRatio: 2.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    overlay.remove();
    if (bytes == null) throw StateError('encode failed');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/railpariksha_share_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));

    await SharePlus.instance.share(ShareParams(text: text, files: [XFile(file.path)]));
  } catch (_) {
    // Best-effort fallback: a failed image render shouldn't block sharing outright.
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
