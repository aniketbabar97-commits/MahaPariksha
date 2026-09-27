import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/design_system.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/topic_relations.dart';
import 'quiz_screen.dart';

/// A radial mind-map of how the syllabus categories relate to each other —
/// e.g. "Fines & Black Points" sits at the centre because it penalizes
/// violations from most other categories, while "Roundabouts &
/// Intersections" links to "Traffic Rules & Right of Way" and "Highway
/// Driving" through shared right-of-way/lane-discipline logic. Tapping any
/// node jumps straight into practising that category.
class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final scope = AppScopeProvider.of(context);
    final bundle = scope.bundle!;
    final lang = scope.lang;
    final categories = bundle.categories;
    final central = categories.firstWhere(
      (c) => c.id == mindMapCentralCategory,
      orElse: () => categories.first,
    );
    final others = categories.where((c) => c.id != central.id).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Topic Mind Map')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight) - 32;
          final center = Offset(constraints.maxWidth / 2, size / 2 + 16);
          final radius = size / 2 - 44;
          final positions = <String, Offset>{central.id: center};
          for (int i = 0; i < others.length; i++) {
            final angle = -math.pi / 2 + i * (2 * math.pi / others.length);
            positions[others[i].id] = center + Offset(radius * math.cos(angle), radius * math.sin(angle));
          }

          final highlighted = _selected == null
              ? <String>{}
              : {_selected!, ...relatedCategories(_selected!)};

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _EdgePainter(
                    positions: positions,
                    relations: topicRelations,
                    highlighted: _selected == null ? null : highlighted,
                  ),
                ),
              ),
              for (final c in categories)
                _node(context, c, positions[c.id]!, isCentral: c.id == central.id, lang: lang,
                    dimmed: _selected != null && !highlighted.contains(c.id)),
              if (_selected != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _detailCard(context, bundle, _selected!, lang),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _node(BuildContext context, Category c, Offset pos, {required bool isCentral, required String lang, required bool dimmed}) {
    final size = isCentral ? 96.0 : 78.0;
    final color = isCentral ? RukhsaColors.gold : RukhsaColors.blue;
    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      width: size,
      height: size,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.35 : 1,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: () => setState(() => _selected = _selected == c.id ? null : c.id),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: isCentral ? 0.95 : 0.12),
              border: Border.all(color: color, width: isCentral ? 0 : 1.5),
              boxShadow: isCentral
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)]
                  : null,
            ),
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text(
                c.name(lang),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isCentral ? 12 : 11,
                  fontWeight: FontWeight.w800,
                  color: isCentral ? RukhsaColors.blueDark : color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailCard(BuildContext context, ContentBundle bundle, String categoryId, String lang) {
    final category = bundle.categories.firstWhere((c) => c.id == categoryId);
    final related = <String>[];
    for (final id in relatedCategories(categoryId)) {
      final matches = bundle.categories.where((c) => c.id == id);
      if (matches.isNotEmpty) related.add(matches.first.name(lang));
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(category.name(lang), style: AppType.h2),
          const SizedBox(height: 6),
          Text(
            related.isEmpty ? 'No linked topics.' : 'Connects with: ${related.join(', ')}',
            style: AppType.caption.copyWith(color: Theme.of(context).hintColor, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => QuizScreen(categoryId: categoryId)),
              ),
              child: const Text('Practise this topic'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  final Map<String, Offset> positions;
  final Map<String, Set<String>> relations;
  final Set<String>? highlighted;
  _EdgePainter({required this.positions, required this.relations, required this.highlighted});

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = <String>{};
    for (final entry in relations.entries) {
      final a = positions[entry.key];
      if (a == null) continue;
      for (final other in entry.value) {
        final key = ([entry.key, other]..sort()).join('|');
        if (drawn.contains(key)) continue;
        drawn.add(key);
        final b = positions[other];
        if (b == null) continue;
        final isHighlighted = highlighted == null || (highlighted!.contains(entry.key) && highlighted!.contains(other));
        final paint = Paint()
          ..color = isHighlighted ? RukhsaColors.gold.withValues(alpha: 0.7) : RukhsaColors.blue.withValues(alpha: 0.12)
          ..strokeWidth = isHighlighted ? 2.4 : 1.4;
        canvas.drawLine(a, b, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) => oldDelegate.highlighted != highlighted;
}
