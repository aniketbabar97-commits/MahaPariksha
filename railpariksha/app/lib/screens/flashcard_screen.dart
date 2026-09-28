import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/celebrate.dart';
import '../widgets/common.dart';

/// Swipe right = "I know it", left = "review again". Tap to flip.
class FlashcardScreen extends StatefulWidget {
  final String? subject;
  const FlashcardScreen({super.key, this.subject});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late List<Flashcard> deck;
  int index = 0;
  int known = 0;
  bool flipped = false;
  double drag = 0;
  late String cLang;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    deck = s.builder.dueCards(subject: widget.subject, limit: 20);
    cLang = s.progress.lang;
  }

  Future<void> _answer(bool good) async {
    if (index >= deck.length) return;
    HapticFeedback.selectionClick();
    final r = AppScope.read(context).progress.reviewCard(deck[index].id, good);
    if (good) {
      known++;
    } else {
      deck.add(deck[index]); // see it again this session
    }
    setState(() {
      index++;
      flipped = false;
      drag = 0;
    });
    await celebrate(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final done = index >= deck.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('फ्लैशकार्ड', 'Flashcards')),
        actions: [
          IconButton(
            tooltip: context.tr('भाषा बदलें', 'Switch language'),
            icon: Text(cLang == 'en' ? 'हिं' : 'EN', style: const TextStyle(fontWeight: FontWeight.w900)),
            onPressed: () => setState(() => cLang = cLang == 'en' ? 'hi' : 'en'),
          ),
        ],
      ),
      body: deck.isEmpty
          ? EmptyState(
              icon: Icons.celebration,
              text: context.tr('आज रिवीज़न के लिए कोई कार्ड बाकी नहीं! कल फिर आएं। 🎉', 'No cards due today! Come back tomorrow. 🎉'))
          : done
              ? _summary(context)
              : _deck(context),
    );
  }

  Widget _summary(BuildContext context) => EmptyState(
        icon: Icons.emoji_events,
        text: context.tr('शाबाश! $known कार्ड याद रहे। 🧠\nअगला रिवीज़न सही समय पर अपने आप आ जाएगा।',
            'Well done! $known cards remembered. 🧠\nNext reviews are scheduled automatically.'),
      );

  Widget _deck(BuildContext context) {
    final c = deck[index];
    final s = context.scope;
    final subject = s.repo.subject(c.subject);
    final width = MediaQuery.of(context).size.width;
    return Column(children: [
      LinearProgressIndicator(value: index / deck.length, color: BrandColors.saffron, minHeight: 5),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text('${index + 1} / ${deck.length} · ${subject?.name.of(cLang) ?? ''}',
            style: TextStyle(color: Theme.of(context).hintColor)),
      ),
      Expanded(
        child: GestureDetector(
          onTap: () => setState(() => flipped = !flipped),
          onHorizontalDragUpdate: (d) => setState(() => drag += d.delta.dx),
          onHorizontalDragEnd: (_) {
            if (drag > width * 0.25) {
              _answer(true);
            } else if (drag < -width * 0.25) {
              _answer(false);
            } else {
              setState(() => drag = 0);
            }
          },
          child: Transform.translate(
            offset: Offset(drag, 0),
            child: Transform.rotate(
              angle: drag / width * 0.3,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('${c.id}-$index'),
                tween: Tween(begin: 0, end: flipped ? pi : 0),
                duration: const Duration(milliseconds: 350),
                builder: (context, a, _) {
                  final showBack = a > pi / 2;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(a),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(showBack ? pi : 0),
                      child: _face(context, showBack ? c.back.of(cLang) : c.front.of(cLang), showBack),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: BrandColors.wrong),
                icon: const Icon(Icons.replay),
                label: Text(context.tr('फिर देखें', 'Again')),
                onPressed: () => _answer(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: BrandColors.correct),
                icon: const Icon(Icons.check),
                label: Text(context.tr('मुझे आता है', 'I know it')),
                onPressed: () => _answer(true),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _face(BuildContext context, String text, bool back) {
    final hint = drag > 30
        ? BrandColors.correct
        : drag < -30
            ? BrandColors.wrong
            : null;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: back ? null : BrandColors.heroGradient,
        color: back ? Theme.of(context).cardTheme.color : null,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: hint ?? Colors.transparent, width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(back ? Icons.lightbulb : Icons.help_outline, color: back ? BrandColors.saffron : BrandColors.sunrise, size: 36),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22, height: 1.45, fontWeight: FontWeight.w700, color: back ? null : Colors.white)),
            const SizedBox(height: 16),
            if (!back)
              Text(context.tr('उत्तर देखने के लिए टैप करें', 'Tap to reveal'),
                  style: const TextStyle(color: Colors.white70)),
          ]),
        ),
      ),
    );
  }
}
