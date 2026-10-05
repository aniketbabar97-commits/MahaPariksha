import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../core/ads.dart';

/// Icon for a GK booster category, keyed by the id strings used in
/// content/gk_booster.json (distinct from [subjectIcon]'s question-bank set).
IconData _boosterIcon(String name) {
  const map = {
    'calendar_month': Icons.calendar_month,
    'account_balance': Icons.account_balance,
    'military_tech': Icons.military_tech,
    'menu_book': Icons.menu_book,
    'park': Icons.park,
    'gavel': Icons.gavel,
  };
  return map[name] ?? Icons.menu_book;
}

const _boosterColors = [
  BrandColors.saffron,
  BrandColors.sky,
  BrandColors.correct,
  Color(0xFF8E5CD9),
  BrandColors.skyLight,
  Color(0xFFE0457B),
];

/// GK Booster: browsable static reference lists aspirants cram before the
/// exam -- Important Days, Govt Schemes, Awards, Books & Authors, National
/// Parks, Committees & Commissions. These are read/browse lists, not quiz
/// questions (the MCQ bank already covers this territory separately) --
/// see content/gk_booster.json for the data and pipeline/validate.py for
/// its schema check.
class GkBoosterScreen extends StatelessWidget {
  const GkBoosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final lang = context.lang;
    final categories = s.repo.gkBooster;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('जीके बूस्टर 🚀', 'GK Booster 🚀'))),
      body: categories.isEmpty
          ? EmptyState(
              icon: Icons.bolt,
              text: context.tr('जीके बूस्टर लिस्ट जल्द आ रही हैं।', 'GK Booster lists are coming soon.'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Text(
                  context.tr('परीक्षा से पहले रटने लायक रेफरेंस लिस्ट — दिवस, योजनाएं, पुरस्कार और बहुत कुछ।',
                      'Cram-ready reference lists for last-minute revision — days, schemes, awards and more.'),
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                ),
                const SizedBox(height: Spacing.lg),
                for (int i = 0; i < categories.length; i++) ...[
                  _CategoryCard(category: categories[i], color: _boosterColors[i % _boosterColors.length], lang: lang),
                  const SizedBox(height: Spacing.md),
                ],
                const AdSlot(),
              ],
            ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final GkBoosterCategory category;
  final Color color;
  final String lang;
  const _CategoryCard({required this.category, required this.color, required this.lang});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          push(context, (_) => GkBoosterCategoryScreen(category: category));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(_boosterIcon(category.icon), color: BrandColors.readable(context, color)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(category.name.of(lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  context.tr('${category.items.length} प्रविष्टियां', '${category.items.length} entries'),
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                ),
              ]),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
          ]),
        ),
      ),
      ),
    );
  }
}

/// A single category's reference list, with an inline substring search
/// (debounced like [SearchScreen]) since some categories run 30-40 entries.
class GkBoosterCategoryScreen extends StatefulWidget {
  final GkBoosterCategory category;
  const GkBoosterCategoryScreen({super.key, required this.category});

  @override
  State<GkBoosterCategoryScreen> createState() => _GkBoosterCategoryScreenState();
}

class _GkBoosterCategoryScreenState extends State<GkBoosterCategoryScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Cheap listener: only rebuilds the clear button immediately, matching
    // SearchScreen's pattern. The actual filtering below runs off `_query`,
    // which only changes once the debounce timer fires.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final needle = _query.toLowerCase();
    final items = needle.isEmpty
        ? widget.category.items
        : widget.category.items
            .where((it) =>
                it.title.hi.toLowerCase().contains(needle) ||
                it.title.en.toLowerCase().contains(needle) ||
                it.detail.hi.toLowerCase().contains(needle) ||
                it.detail.en.toLowerCase().contains(needle))
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name.of(lang))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: context.tr('इस लिस्ट में खोजें...', 'Search this list...'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        _debounce?.cancel();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Corners.md), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  text: context.tr('कोई मिलान नहीं मिला।', 'No matches found.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(it.title.of(lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                          const SizedBox(height: 4),
                          Text(it.detail.of(lang), style: const TextStyle(fontSize: 13.5, height: 1.4)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
