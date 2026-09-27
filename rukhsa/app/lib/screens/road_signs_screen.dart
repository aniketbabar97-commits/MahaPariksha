import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/design_system.dart';
import '../core/theme.dart';
import '../data/road_signs.dart';
import '../widgets/road_sign_painter.dart';

/// Dedicated UAE road-sign visual library: real sign shapes/colors grouped
/// by category, tappable to reveal name + meaning. This closes a gap versus
/// theorytestrta.com / yallapass.ae, neither of which has a drawn sign
/// gallery like this.
class RoadSignsScreen extends StatefulWidget {
  const RoadSignsScreen({super.key});

  @override
  State<RoadSignsScreen> createState() => _RoadSignsScreenState();
}

class _RoadSignsScreenState extends State<RoadSignsScreen> {
  String? _filter; // null = all

  @override
  Widget build(BuildContext context) {
    final lang = AppScopeProvider.of(context).lang;
    final isAr = lang == 'ar';
    final signs = _filter == null
        ? uaeRoadSigns
        : uaeRoadSigns.where((s) => s.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'إشارات الطريق' : 'Road Sign Library')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              children: [
                _FilterChip(label: isAr ? 'الكل' : 'All', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                for (final c in roadSignCategories)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: _FilterChip(
                      label: roadSignCategoryLabel(c),
                      selected: _filter == c,
                      onTap: () => setState(() => _filter = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.82,
              ),
              itemCount: signs.length,
              itemBuilder: (context, i) {
                final s = signs[i];
                return _SignCell(sign: s, isAr: isAr);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: RukhsaColors.gold.withValues(alpha: 0.28),
    );
  }
}

class _SignCell extends StatelessWidget {
  final RoadSign sign;
  final bool isAr;
  const _SignCell({required this.sign, required this.isAr});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () => _showDetail(context, sign, isAr),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Center(child: RoadSignIcon(sign: sign, size: 56))),
          const SizedBox(height: 6),
          Text(
            isAr ? sign.nameAr : sign.nameEn,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption,
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, RoadSign sign, bool isAr) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoadSignIcon(sign: sign, size: 96),
            const SizedBox(height: AppSpacing.lg),
            Text(isAr ? sign.nameAr : sign.nameEn, style: AppType.h1, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            AppBadge(label: roadSignCategoryLabel(sign.category)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isAr ? sign.meaningAr : sign.meaningEn,
              textAlign: TextAlign.center,
              style: AppType.body,
            ),
          ],
        ),
      ),
    );
  }
}
