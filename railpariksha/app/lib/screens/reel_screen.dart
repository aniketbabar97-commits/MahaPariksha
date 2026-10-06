import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/celebrate.dart';
import '../widgets/common.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/ads_config.dart';

/// How many items each growth batch adds to the queue.
const int _kBatchSize = 40;

/// Grow the queue once the user is this close to running out of cards, so a
/// fast swiper never hits a dead end.
const int _kGrowThreshold = 5;

enum _CardKind { mcq, flashcard, motivation, ad }

/// One entry in the endless reel. Exactly one of [question]/[card]/[tip] is set,
/// matching [kind].
class _ReelEntry {
  final _CardKind kind;
  final Question? question;
  final Flashcard? card;
  final Motivation? tip;
  final NativeAd? ad;
  const _ReelEntry.mcq(this.question)
      : kind = _CardKind.mcq,
        card = null,
        tip = null,
        ad = null;
  const _ReelEntry.flashcard(this.card)
      : kind = _CardKind.flashcard,
        question = null,
        tip = null,
        ad = null;
  const _ReelEntry.motivation(this.tip)
      : kind = _CardKind.motivation,
        question = null,
        card = null,
        ad = null;

  /// A sponsored card. Only ever created for an ad that has already loaded.
  const _ReelEntry.sponsored(this.ad)
      : kind = _CardKind.ad,
        question = null,
        card = null,
        tip = null;
}

/// TikTok/Reels-style endless vertical feed mixing quick MCQs, flashcards and
/// motivation cards, drawn from the current exam's content pool.
///
/// Performance note: the question bank can grow past 20,000 items, so this
/// screen never copies or shuffles the whole pool. It reads the exam's
/// already-indexed question/flashcard lists (`ContentRepo.questionsFor` /
/// `flashcardsFor`, backed by the `_questionsBySubject`/`_flashcardsBySubject`
/// maps) once in [initState], then draws random single items from those lists
/// to build small batches ([_kBatchSize] at a time) — O(batch), never O(pool).
class ReelScreen extends StatefulWidget {
  const ReelScreen({super.key});

  @override
  State<ReelScreen> createState() => _ReelScreenState();
}

class _ReelScreenState extends State<ReelScreen> {
  final _rnd = Random();
  final _pageController = PageController();
  final List<_ReelEntry> _queue = [];

  List<Question> _questionPool = const [];
  List<Flashcard> _flashcardPool = const [];
  List<Motivation> _motivationPool = const [];

  bool _hasExam = false;
  String _lang = 'hi';
  int _currentIndex = 0;

  /// Native ads that have finished loading and are waiting to be dropped into the feed. A card
  /// is only inserted for a loaded ad, so a swipe never lands on an empty "sponsored" page.
  final List<NativeAd> _readyAds = [];
  final List<NativeAd> _usedAds = [];
  static const _adEvery = 3;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    _lang = s.progress.lang;
    final exam = s.builder.exam;
    _hasExam = exam != null;
    if (exam == null) return;
    // Read once: these come from the pre-built per-subject indices in
    // ContentRepo, so this is a handful of list concatenations, not a scan
    // over every question/flashcard in the app.
    _questionPool = s.repo.questionsFor(exam);
    _flashcardPool = s.repo.flashcardsFor(exam);
    _motivationPool = s.repo.motivation;
    _queue.addAll(_generateBatch(_kBatchSize));
    if (!s.progress.removedAds) {
      _loadReelAd();
      _loadReelAd();
      _loadReelAd();
    }
  }

  Future<void> _loadReelAd() async {
    try {
      await NativeAd(
        adUnitId: AdIds.native,
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(templateType: TemplateType.medium),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            _readyAds.add(ad as NativeAd);
          },
          onAdFailedToLoad: (ad, _) => ad.dispose(),
        ),
      ).load();
    } catch (_) {
      // No ads plugin: the feed simply has no sponsored cards.
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final ad in [..._readyAds, ..._usedAds]) {
      ad.dispose();
    }
    super.dispose();
  }

  /// Builds a batch mixing roughly 3-4 MCQs, then a flashcard, then a
  /// motivation card, repeated — with a light windowed shuffle so the rhythm
  /// isn't perfectly predictable. Items are drawn at random (with
  /// replacement) from the pools, so the feed loops forever through the exam's
  /// content instead of ever running out.
  List<_ReelEntry> _generateBatch(int count) {
    if (_questionPool.isEmpty && _flashcardPool.isEmpty && _motivationPool.isEmpty) return const [];
    final out = <_ReelEntry>[];
    while (out.length < count) {
      final mcqCount = _questionPool.isEmpty ? 0 : 3 + _rnd.nextInt(2); // 3-4
      for (var i = 0; i < mcqCount; i++) {
        out.add(_ReelEntry.mcq(_questionPool[_rnd.nextInt(_questionPool.length)]));
      }
      if (_flashcardPool.isNotEmpty) {
        out.add(_ReelEntry.flashcard(_flashcardPool[_rnd.nextInt(_flashcardPool.length)]));
      }
      if (_motivationPool.isNotEmpty) {
        out.add(_ReelEntry.motivation(_motivationPool[_rnd.nextInt(_motivationPool.length)]));
      }
      // Pools might be empty for a niche exam; guard against an infinite loop.
      if (mcqCount == 0 && _flashcardPool.isEmpty && _motivationPool.isEmpty) break;
    }
    // Light windowed shuffle: mix order inside small windows so the "3-4
    // MCQ, 1 flashcard, 1 motivation" pattern doesn't feel perfectly rigid,
    // without losing the rough interleave ratio.
    for (var start = 0; start < out.length; start += 6) {
      final end = min(start + 6, out.length);
      final window = out.sublist(start, end)..shuffle(_rnd);
      for (var i = start; i < end; i++) {
        out[i] = window[i - start];
      }
    }
    return out;
  }

  void _onPageChanged(int i) {
    HapticFeedback.selectionClick();
    _currentIndex = i;
    // Every few cards, slot in a loaded sponsored card a couple of pages ahead.
    if (i > 0 && i % _adEvery == 0 && _readyAds.isNotEmpty) {
      final ad = _readyAds.removeAt(0);
      _usedAds.add(ad);
      setState(() => _queue.insert(min(i + 2, _queue.length), _ReelEntry.sponsored(ad)));
      _loadReelAd();
    }
    if (_queue.length - i <= _kGrowThreshold) {
      final more = _generateBatch(_kBatchSize);
      if (more.isNotEmpty) setState(() => _queue.addAll(more));
    }
  }

  /// Called by a card once it wants to move on (answered, or reviewed). Only
  /// animates if the user hasn't already swiped away manually.
  void _advanceFrom(int index) {
    if (_currentIndex != index || !_pageController.hasClients) return;
    if (index + 1 >= _queue.length) return;
    _pageController.animateToPage(index + 1,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasExam) return const NoExamState();
    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('रील मोड', 'Reel Mode'))),
        body: EmptyState(
          icon: Icons.smart_display_outlined,
          text: context.tr('इस परीक्षा के लिए अभी कंटेंट नहीं है।', 'No content for this exam yet.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: context.tr('बंद करें', 'Close'),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            tooltip: context.tr('भाषा बदलें', 'Switch language'),
            icon: Text(_lang == 'en' ? 'हिं' : 'EN',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _lang = _lang == 'en' ? 'hi' : 'en');
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _queue.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, i) {
          final entry = _queue[i];
          return KeyedSubtree(
            key: ValueKey(i),
            child: switch (entry.kind) {
              _CardKind.mcq => _McqCard(
                  key: ValueKey('mcq-$i-${entry.question!.id}'),
                  q: entry.question!,
                  lang: _lang,
                  onAdvance: () => _advanceFrom(i),
                ),
              _CardKind.flashcard => _FlashcardCard(
                  key: ValueKey('card-$i-${entry.card!.id}'),
                  c: entry.card!,
                  lang: _lang,
                  onAdvance: () => _advanceFrom(i),
                ),
              _CardKind.motivation => _MotivationCard(
                  key: ValueKey('tip-$i-${entry.tip!.id}'),
                  m: entry.tip!,
                  lang: _lang,
                ),
              _CardKind.ad => _SponsoredCard(key: ValueKey('ad-$i'), ad: entry.ad!),
            },
          );
        },
      ),
    );
  }
}

const _labelsHi = ['अ', 'ब', 'क', 'ड'];
const _labelsEn = ['A', 'B', 'C', 'D'];

enum _OptState { idle, correct, wrong, dim }

/// Quick MCQ card: one question, 4 tappable options, instant color feedback,
/// then auto-advances to the next reel card after a short beat.
class _McqCard extends StatefulWidget {
  final Question q;
  final String lang;
  final VoidCallback onAdvance;
  const _McqCard({super.key, required this.q, required this.lang, required this.onAdvance});

  @override
  State<_McqCard> createState() => _McqCardState();
}

class _McqCardState extends State<_McqCard> {
  int? selected;
  int? xpEarned;

  Future<void> _select(int i) async {
    if (selected != null) return;
    final correct = i == widget.q.answer;
    setState(() => selected = i);
    HapticFeedback.lightImpact();
    if (!correct) HapticFeedback.vibrate();
    final r = context.scope.progress.recordAnswer(widget.q.id, correct);
    if (mounted) setState(() => xpEarned = r.xp);
    await Future.delayed(const Duration(milliseconds: 900));
    // The reel is one of the app's main engagement loops (endless swipe,
    // same recordAnswer/Reward as the regular quiz) but was missing the
    // level-up/streak/goal celebration quiz_screen.dart already has -- a
    // level-up mid-reel silently gave XP with no payoff. Shown after the
    // correct/wrong flash settles, before advancing to the next card.
    if (mounted) await celebrate(context, r);
    if (mounted) widget.onAdvance();
  }

  _OptState _state(int i) {
    if (selected == null) return _OptState.idle;
    if (i == widget.q.answer) return _OptState.correct;
    if (i == selected) return _OptState.wrong;
    return _OptState.dim;
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.lang == 'en' ? _labelsEn : _labelsHi;
    final options = widget.q.options(widget.lang);
    final subject = context.scope.repo.subject(widget.q.subject);
    return Container(
      decoration: const BoxDecoration(gradient: BrandColors.heroGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 80, Spacing.lg, Spacing.xl),
          // A long question + four long options can be taller than a small phone. Scaling the
          // card down to fit (rather than scrolling it) keeps the vertical swipe to the next card.
          child: LayoutBuilder(
            builder: (context, c) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: c.maxWidth,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(Icons.bolt, color: BrandColors.sunrise, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(subject?.name.of(widget.lang) ?? context.tr('झटपट सवाल', 'Quick question'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: BrandColors.onGradientMuted, fontWeight: FontWeight.w700)),
              ),
              if (xpEarned != null) ...[
                const Spacer(),
                AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                    child: Text('+$xpEarned XP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: Spacing.lg),
            Text(widget.q.text.of(widget.lang),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.4)),
            const SizedBox(height: Spacing.xl),
            for (var i = 0; i < options.length; i++)
              _ReelOption(label: labels[i], text: options[i], state: _state(i), onTap: () => _select(i)),
            const SizedBox(height: Spacing.lg),
            Center(
              child: Text(context.tr('↑ ऊपर स्वाइप करें अगले के लिए', '↑ Swipe up for next'),
                  style: const TextStyle(color: BrandColors.onGradientMuted, fontSize: 13)),
            ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReelOption extends StatelessWidget {
  final String label;
  final String text;
  final _OptState state;
  final VoidCallback onTap;
  const _ReelOption({required this.label, required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (Color border, Color bg, IconData? icon) = switch (state) {
      _OptState.correct => (BrandColors.correct, BrandColors.correct.withValues(alpha: 0.28), Icons.check_circle),
      _OptState.wrong => (BrandColors.wrong, BrandColors.wrong.withValues(alpha: 0.28), Icons.cancel),
      _OptState.dim => (Colors.white24, Colors.white10, null),
      _OptState.idle => (Colors.white38, Colors.white.withValues(alpha: 0.12), null),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm + 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: 2), borderRadius: BorderRadius.circular(Corners.md)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Corners.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(children: [
                // A dark tint under the letter: white on a white-tinted circle over the gradient was 2.99:1.
                CircleAvatar(radius: 14, backgroundColor: Colors.black26, child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                // Bold: white on the option tint over the blue gradient measures 4.47:1, a hair under AA
                // for regular text; bold 16 px counts as large text (3:1) and reads better on a reel anyway.
                Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.3, fontWeight: FontWeight.w700))),
                if (icon != null) Icon(icon, color: border),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flashcard reel card: tap to flip, then "Again"/"Know it" records into the
/// SAME [CardState] the Revise screen's spaced-repetition tracking uses
/// (`Progress.reviewCard`), so a review here isn't wasted/duplicated — it
/// pushes the card's next-due date out exactly as Revise would. If the user
/// just swipes past without judging it (never flips or never taps a button),
/// nothing is recorded, so it can't corrupt existing due-card state.
/// Readable text colour on the saffron gradient.
const _onSaffron = BrandColors.onSaffron;

class _FlashcardCard extends StatefulWidget {
  final Flashcard c;
  final String lang;
  final VoidCallback onAdvance;
  const _FlashcardCard({super.key, required this.c, required this.lang, required this.onAdvance});

  @override
  State<_FlashcardCard> createState() => _FlashcardCardState();
}

class _FlashcardCardState extends State<_FlashcardCard> {
  bool flipped = false;
  bool answered = false;

  Future<void> _answer(bool good) async {
    if (answered) return;
    answered = true;
    HapticFeedback.selectionClick();
    final r = context.scope.progress.reviewCard(widget.c.id, good);
    // Same gap as _McqCard's celebrate() wiring above -- this card's Reward
    // was being discarded, silently dropping a level-up/streak/goal payoff.
    if (mounted) await celebrate(context, r);
    if (mounted) widget.onAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final subject = context.scope.repo.subject(widget.c.subject);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: dark ? const Color(0xFF0E1320) : BrandColors.sky,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 80, Spacing.lg, Spacing.xl),
          child: LayoutBuilder(
            builder: (context, c) => FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: c.maxWidth,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(subject?.name.of(widget.lang) ?? context.tr('फ्लैशकार्ड', 'Flashcard'),
                  style: const TextStyle(color: BrandColors.onGradientMuted, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: Spacing.lg),
            GestureDetector(
              onTap: () => setState(() => flipped = !flipped),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                child: Container(
                  key: ValueKey(flipped),
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: flipped ? null : BrandColors.fireGradient,
                    color: flipped ? const Color(0xFF1A2133) : null,
                    borderRadius: BorderRadius.circular(Corners.xl),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(flipped ? Icons.lightbulb : Icons.help_outline, color: flipped ? Colors.white : _onSaffron, size: 32),
                    const SizedBox(height: 14),
                    Text(flipped ? widget.c.back.of(widget.lang) : widget.c.front.of(widget.lang),
                        textAlign: TextAlign.center,
                        // White on saffron was ~1.6:1 contrast; the front uses a dark brown instead.
                        style: TextStyle(
                            color: flipped ? Colors.white : _onSaffron, fontSize: 21, fontWeight: FontWeight.w800, height: 1.4)),
                    if (!flipped) ...[
                      const SizedBox(height: 14),
                      Text(context.tr('टैप करके उत्तर देखें', 'Tap to reveal'),
                          style: TextStyle(color: _onSaffron.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ),
              ),
            ),
            const SizedBox(height: Spacing.xl),
            if (flipped)
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: BrandColors.wrong, side: const BorderSide(color: BrandColors.wrong)),
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
              ])
            else
              Text(context.tr('↑ ऊपर स्वाइप करें अगले के लिए', '↑ Swipe up for next'), style: const TextStyle(color: BrandColors.onGradientMuted, fontSize: 13)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sponsored native ad as a full-page reel card: clearly labelled, no buttons of ours near it.
class _SponsoredCard extends StatelessWidget {
  final NativeAd ad;
  const _SponsoredCard({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: BrandColors.heroGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 80, Spacing.lg, Spacing.xl),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(context.tr('प्रायोजित', 'Sponsored'),
                style: const TextStyle(color: BrandColors.onGradientMuted, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(Corners.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 320, maxHeight: 420),
                child: AdWidget(ad: ad),
              ),
            ),
            const SizedBox(height: Spacing.xl),
            Text(context.tr('↑ ऊपर स्वाइप करें अगले के लिए', '↑ Swipe up for next'),
                style: const TextStyle(color: BrandColors.onGradientMuted, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

/// Motivation card: swipe-only rhythm break, no interaction, styled boldly.
class _MotivationCard extends StatelessWidget {
  final Motivation m;
  final String lang;
  const _MotivationCard({super.key, required this.m, required this.lang});

  @override
  Widget build(BuildContext context) {
    final icon = switch (m.type) {
      'story' => Icons.auto_stories,
      'tip' => Icons.tips_and_updates,
      _ => Icons.format_quote,
    };
    final kicker = switch (m.type) {
      'story' => context.tr('प्रेरक कहानी', 'Inspiring story'),
      'tip' => context.tr('अध्ययन टिप', 'Study tip'),
      _ => context.tr('सुविचार', 'Quote'),
    };
    return Container(
      decoration: const BoxDecoration(gradient: BrandColors.fireGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xxl, 80, Spacing.xxl, Spacing.xl),
          child: LayoutBuilder(
            builder: (context, c) => FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: c.maxWidth,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(icon, color: _onSaffron, size: 44),
            const SizedBox(height: Spacing.lg),
            Text(kicker.toUpperCase(),
                style: TextStyle(color: _onSaffron.withValues(alpha: 0.7), fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: Spacing.lg),
            Text(m.text.of(lang),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _onSaffron, fontSize: 26, fontWeight: FontWeight.w900, height: 1.4)),
            if (m.by != null) ...[
              const SizedBox(height: Spacing.lg),
              Text('— ${m.by}',
                  style: TextStyle(color: _onSaffron.withValues(alpha: 0.75), fontStyle: FontStyle.italic, fontSize: 16)),
            ],
            const SizedBox(height: Spacing.xxl),
            Text(context.tr('↑ ऊपर स्वाइप करें', '↑ Swipe up'),
                style: TextStyle(color: _onSaffron.withValues(alpha: 0.6), fontSize: 13)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
