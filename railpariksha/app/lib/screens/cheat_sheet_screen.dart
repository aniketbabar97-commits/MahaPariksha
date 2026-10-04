import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../core/ads.dart';

const _catColors = [
  BrandColors.saffron,
  BrandColors.skyLight,
  BrandColors.correct,
  Color(0xFF8E5CD9),
  Color(0xFFE0457B),
  Color(0xFF14A3A3),
];

/// Exam-day cram sheet for a subject: every category's formulas/facts packed
/// as dense one-line entries, expand/collapse like [MindMapView] but without
/// the explanatory prose of [TopicScreen]'s notes -- this is the "look at
/// this 5 minutes before the exam" version, not the learning one.
class CheatSheetScreen extends StatefulWidget {
  final Subject subject;
  const CheatSheetScreen({super.key, required this.subject});

  @override
  State<CheatSheetScreen> createState() => _CheatSheetScreenState();
}

class _CheatSheetScreenState extends State<CheatSheetScreen> {
  final Set<int> open = {0};

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final lang = context.lang;
    final sheets = s.repo.cheatSheetsFor(widget.subject.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('चीट शीट ⚡ ${widget.subject.name.of(lang)}', 'Cheat Sheet ⚡ ${widget.subject.name.of(lang)}')),
      ),
      body: sheets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xxl),
                child: Text(
                  context.tr('इस विषय की चीट शीट जल्द ही आ रही है।', "This subject's cheat sheet is coming soon."),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      context.tr('परीक्षा से ठीक पहले एक बार दोहराएँ 🔁', 'One last revision right before the exam 🔁'),
                      style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => open.length == sheets.length
                          ? open.clear()
                          : open.addAll(List.generate(sheets.length, (i) => i)));
                    },
                    child: Text(open.length == sheets.length
                        ? context.tr('सभी बंद करें', 'Collapse all')
                        : context.tr('सभी खोलें', 'Expand all')),
                  ),
                ]),
                for (var i = 0; i < sheets.length; i++) _category(i, sheets[i], lang),
                      const AdSlot(),
      ],
            ),
    );
  }

  Widget _category(int i, CheatSheet sheet, String lang) {
    final color = _catColors[i % _catColors.length];
    final isOpen = open.contains(i);
    final items = sheet.items(lang);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: isOpen ? 0.10 : 0.06),
          border: Border(left: BorderSide(color: color, width: 5)),
          borderRadius: BorderRadius.circular(Corners.sm + 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            button: true,
            expanded: isOpen,
            child: InkWell(
              borderRadius: BorderRadius.circular(Corners.sm + 2),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => isOpen ? open.remove(i) : open.add(i));
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
                    child: Icon(topicIcon(sheet.topic), color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(sheet.category.of(lang),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
                  ),
                  Text('${items.length}', style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 13)),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.expand_more, color: color),
                  ),
                ]),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: isOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final item in items) _item(item, color),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }

  Widget _item(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
