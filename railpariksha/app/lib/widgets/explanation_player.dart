import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';

/// The closest thing to a "video explanation" this app can realistically
/// ship: every question already has a single explanation string (no
/// structured step data exists across the 25k+ item question bank, and
/// adding that is a separate, much larger content task) -- this widget
/// splits that string into sentences and plays them back one at a time,
/// auto-advancing on a reading-speed timer with a video-style segmented
/// progress bar and play/pause control, instead of dumping the whole
/// paragraph on screen at once. Works on every existing explanation with
/// zero new content, in both Hindi and English (splits on ./!/? and the
/// Hindi sentence-ending danda "।").
class ExplanationPlayer extends StatefulWidget {
  final String text;
  const ExplanationPlayer({super.key, required this.text});

  static final _sentenceSplit = RegExp(r'(?<=[.!?।])\s+');

  @override
  State<ExplanationPlayer> createState() => _ExplanationPlayerState();
}

class _ExplanationPlayerState extends State<ExplanationPlayer> {
  late final List<String> _sentences = widget.text
      .split(ExplanationPlayer._sentenceSplit)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  int _index = 0;
  bool _playing = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _durationFor(String sentence) {
    // Rough reading-speed estimate rather than a fixed interval, so a short
    // sentence doesn't linger and a long one doesn't fly past unread.
    final ms = 900 + sentence.length * 35;
    return Duration(milliseconds: ms.clamp(1200, 5000));
  }

  void _play() {
    if (_sentences.length <= 1) return;
    setState(() => _playing = true);
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = Timer(_durationFor(_sentences[_index]), () {
      if (!mounted) return;
      if (_index >= _sentences.length - 1) {
        setState(() => _playing = false);
        return;
      }
      setState(() => _index++);
      _scheduleNext();
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _playing = false);
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _index = 0;
      _playing = true;
    });
    _scheduleNext();
  }

  @override
  Widget build(BuildContext context) {
    if (_sentences.length <= 1) {
      // Nothing to "play" -- a single sentence is already fully shown, so
      // the player controls would just be dead weight. Plain text is right.
      return Text(widget.text, style: const TextStyle(height: 1.5));
    }
    final done = !_playing && _index == _sentences.length - 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (var i = 0; i < _sentences.length; i++)
          Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i <= _index ? BrandColors.sky : Theme.of(context).hintColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 10),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim), child: child),
        ),
        child: Text(_sentences[_index], key: ValueKey(_index), style: const TextStyle(height: 1.5, fontSize: 15)),
      ),
      const SizedBox(height: 10),
      Row(children: [
        IconButton.filledTonal(
          icon: Icon(done ? Icons.replay : (_playing ? Icons.pause : Icons.play_arrow)),
          tooltip: done
              ? context.tr('फिर से चलाएं', 'Replay')
              : (_playing ? context.tr('रोकें', 'Pause') : context.tr('चलाएं', 'Play')),
          onPressed: () {
            HapticFeedback.selectionClick();
            if (done) {
              _restart();
            } else if (_playing) {
              _pause();
            } else {
              _play();
            }
          },
        ),
        const SizedBox(width: 8),
        Text(context.tr('${_index + 1} / ${_sentences.length}', '${_index + 1} / ${_sentences.length}'),
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
      ]),
    ]);
  }
}
