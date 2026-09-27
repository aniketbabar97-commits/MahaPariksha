import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/design_system.dart';
import '../core/theme.dart';
import '../logic/flashcard_engine.dart';

/// Spaced-repetition flashcards generated from the question bank: front is
/// the question, back is the correct answer + explanation. Tap to flip,
/// swipe right for "I knew this", left for "I didn't" — both update the
/// SM-2-lite scheduler in [FlashcardScheduler].
class FlashcardsScreen extends StatefulWidget {
  final String? categoryId;
  const FlashcardsScreen({super.key, this.categoryId});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final _scheduler = FlashcardScheduler();
  List<Flashcard> _deck = [];
  bool _loading = true;
  int _index = 0;
  int _knownCount = 0;
  bool _flipped = false;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scope = AppScopeProvider.of(context);
    final questions = widget.categoryId == null
        ? scope.filteredQuestions
        : scope.filteredQuestions.where((q) => q.category == widget.categoryId).toList();
    final due = await _scheduler.dueCards(questions, scope.lang, limit: 25);
    if (!mounted) return;
    setState(() {
      _deck = due;
      _loading = false;
    });
  }

  Future<void> _answer(bool knew) async {
    if (_index >= _deck.length) return;
    HapticFeedback.selectionClick();
    await _scheduler.review(_deck[_index].id, knew);
    if (knew) _knownCount++;
    setState(() {
      _index++;
      _flipped = false;
      _drag = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deck.isEmpty
              ? const AppEmptyState(
                  icon: Icons.celebration_outlined,
                  text: 'No cards due for review right now.\nCome back later, or study a category to build your deck.',
                )
              : _index >= _deck.length
                  ? _summary()
                  : _card(context),
    );
  }

  Widget _summary() {
    return AppEmptyState(
      icon: Icons.emoji_events_outlined,
      text: 'Session complete!\n$_knownCount / ${_deck.length} cards you already knew.\nMissed ones will come back sooner.',
    );
  }

  Widget _card(BuildContext context) {
    final c = _deck[_index];
    final width = MediaQuery.of(context).size.width;
    return Column(
      children: [
        LinearProgressIndicator(value: _index / _deck.length, minHeight: 5, color: RukhsaColors.gold),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('${_index + 1} / ${_deck.length}', style: TextStyle(color: Theme.of(context).hintColor)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _flipped = !_flipped),
            onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx),
            onHorizontalDragEnd: (_) {
              if (_drag > width * 0.25) {
                _answer(true);
              } else if (_drag < -width * 0.25) {
                _answer(false);
              } else {
                setState(() => _drag = 0);
              }
            },
            child: Transform.translate(
              offset: Offset(_drag, 0),
              child: Transform.rotate(
                angle: _drag / width * 0.25,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('${c.id}-$_index'),
                  tween: Tween(begin: 0, end: _flipped ? pi : 0),
                  duration: const Duration(milliseconds: 320),
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
                        child: _face(context, showBack ? c.back : c.front, showBack),
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: RukhsaColors.danger),
                    icon: const Icon(Icons.replay),
                    label: const Text("Didn't know"),
                    onPressed: () => _answer(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: RukhsaColors.success, foregroundColor: Colors.white),
                    icon: const Icon(Icons.check),
                    label: const Text('I knew it'),
                    onPressed: () => _answer(true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _face(BuildContext context, String text, bool back) {
    final hint = _drag > 30
        ? RukhsaColors.success
        : _drag < -30
            ? RukhsaColors.danger
            : null;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: back ? null : RukhsaColors.heroGradient,
        color: back ? Theme.of(context).cardColor : null,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: hint ?? Colors.transparent, width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(back ? Icons.lightbulb : Icons.help_outline, color: back ? RukhsaColors.gold : RukhsaColors.goldLight, size: 34),
              const SizedBox(height: AppSpacing.md),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, height: 1.4, fontWeight: FontWeight.w700, color: back ? null : Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              if (!back) const Text('Tap to reveal answer', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
