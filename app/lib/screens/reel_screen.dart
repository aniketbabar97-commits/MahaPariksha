import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../logic/reel_builder.dart';
import '../widgets/celebrate.dart';

/// The endless vertical "Bharari Reel" — swipe up for the next card, forever.
/// This is the low-friction, high-frequency habit loop: no setup, no picking a
/// topic, just open and go. Mixes quick MCQs, flashcards, facts and motivation.
class ReelScreen extends StatefulWidget {
  const ReelScreen({super.key});

  @override
  State<ReelScreen> createState() => _ReelScreenState();
}

class _ReelScreenState extends State<ReelScreen> {
  late final ReelBuilder builder;
  final List<ReelItem> items = [];
  final PageController controller = PageController();
  int viewed = 0;
  int correct = 0;
  int page = 0;
  bool langMr = true;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    builder = ReelBuilder(s.repo, s.progress, s.builder);
    langMr = s.progress.lang != 'en';
    items.addAll(builder.more(24));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() {
      page = i;
      viewed = i + 1;
    });
    HapticFeedback.selectionClick();
    if (i >= items.length - 6) {
      items.addAll(builder.more(20));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          itemCount: items.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, i) => _ReelCard(
            key: ValueKey('${items[i].kind}-$i'),
            item: items[i],
            langMr: langMr,
            onCorrect: () => setState(() => correct++),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              _pillButton(
                icon: Icons.close,
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_fire_department, color: BrandColors.sunrise, size: 18),
                  const SizedBox(width: 4),
                  Text('$viewed', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ]),
              ),
              const Spacer(),
              _pillButton(
                icon: Icons.translate,
                onTap: () => setState(() => langMr = !langMr),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _pillButton({required IconData icon, required VoidCallback onTap}) => Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: Colors.white, size: 20)),
        ),
      );
}

const _labelsMr = ['अ', 'ब', 'क', 'ड'];
const _labelsEn = ['A', 'B', 'C', 'D'];

class _ReelCard extends StatefulWidget {
  final ReelItem item;
  final bool langMr;
  final VoidCallback onCorrect;
  const _ReelCard({super.key, required this.item, required this.langMr, required this.onCorrect});

  @override
  State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard> {
  int? selected;
  bool flipped = false;

  String get lang => widget.langMr ? 'mr' : 'en';

  @override
  Widget build(BuildContext context) {
    switch (widget.item.kind) {
      case ReelKind.question:
        return _questionCard(widget.item.question!);
      case ReelKind.flashcard:
        return _flashcard(widget.item.flashcard!);
      case ReelKind.fact:
        return _factCard(widget.item.fact!, widget.item.factSubject, widget.item.factTopic);
      case ReelKind.motivation:
        return _motivationCard(widget.item.motivation!);
    }
  }

  Widget _frame({required Widget child, required Gradient gradient, String? tag}) => Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 68, 24, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
                      if (tag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration:
                              BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                          child: Text(tag, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      const SizedBox(height: 22),
                      child,
                    ]),
                  ),
                ),
              ),
              Column(children: [
                Icon(Icons.keyboard_arrow_up, color: Colors.white.withValues(alpha: 0.6)),
                Text(widget.langMr ? 'पुढच्यासाठी वर स्वाइप करा' : 'Swipe up for next',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
              ]),
            ]),
          ),
        ),
      );

  Widget _questionCard(Question q) {
    final opts = q.options(lang);
    final labels = widget.langMr ? _labelsMr : _labelsEn;
    return _frame(
      gradient: BrandColors.heroGradient,
      tag: widget.langMr ? '⚡ झटपट प्रश्न' : '⚡ Quick question',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(q.text.of(lang), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.4)),
        const SizedBox(height: 22),
        for (var i = 0; i < opts.length; i++) _option(q, i, opts[i], labels[i]),
        if (selected != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Text(q.explanation.of(lang), style: const TextStyle(color: Colors.white, height: 1.4)),
          ),
        ],
      ]),
    );
  }

  Widget _option(Question q, int i, String text, String label) {
    final isAnswered = selected != null;
    final isCorrect = i == q.answer;
    final isPicked = i == selected;
    final Color bg = !isAnswered
        ? Colors.white.withValues(alpha: 0.14)
        : isCorrect
            ? BrandColors.correct.withValues(alpha: 0.85)
            : isPicked
                ? BrandColors.wrong.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.08);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isAnswered
            ? null
            : () {
                HapticFeedback.lightImpact();
                setState(() => selected = i);
                final r = context.scope.progress.recordAnswer(q.id, i == q.answer);
                if (i == q.answer) widget.onCorrect();
                celebrate(context, r);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            CircleAvatar(radius: 13, backgroundColor: Colors.white24, child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15))),
          ]),
        ),
      ),
    );
  }

  Widget _flashcard(Flashcard c) => GestureDetector(
        onTap: () => setState(() => flipped = !flipped),
        child: _frame(
          gradient: const LinearGradient(colors: [Color(0xFF8E5CD9), Color(0xFFB47FE8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          tag: widget.langMr ? '🎴 फ्लॅशकार्ड' : '🎴 Flashcard',
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(flipped ? Icons.lightbulb : Icons.help_outline, color: Colors.white, size: 32),
            const SizedBox(height: 14),
            Text(
              flipped ? c.back.of(lang) : c.front.of(lang),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (!flipped)
              Text(widget.langMr ? 'उत्तरासाठी टॅप करा' : 'Tap to reveal', style: const TextStyle(color: Colors.white70)),
          ]),
        ),
      );

  Widget _factCard(Bi fact, Subject? subject, Topic? topic) => _frame(
        gradient: const LinearGradient(colors: [Color(0xFF14A3A3), Color(0xFF3DC7C7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        tag: widget.langMr ? '🧠 तुम्हाला माहीत आहे का?' : '🧠 Did you know?',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(fact.of(lang), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.45)),
          if (subject != null) ...[
            const SizedBox(height: 14),
            Text('${subject.name.of(lang)}${topic != null ? ' · ${topic.name.of(lang)}' : ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ]),
      );

  Widget _motivationCard(Motivation m) => _frame(
        gradient: BrandColors.fireGradient,
        tag: switch (m.type) {
          'story' => widget.langMr ? '📖 प्रेरणादायी कथा' : '📖 Inspiring story',
          'tip' => widget.langMr ? '💡 अभ्यास टिप' : '💡 Study tip',
          _ => widget.langMr ? '✨ सुविचार' : '✨ Quote',
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(m.text.of(lang), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700, height: 1.5)),
          if (m.by != null) ...[
            const SizedBox(height: 10),
            Text('— ${m.by}', style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 18),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => SharePlus.instance.share(ShareParams(
                text: '${m.text.of(lang)}${m.by != null ? '\n— ${m.by}' : ''}\n\n${widget.langMr ? 'भरारी ॲपवर रोज नवीन प्रेरणा 🚀' : 'Fresh motivation daily on Bharari 🚀'}')),
          ),
        ]),
      );
}
