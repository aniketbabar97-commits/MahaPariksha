import 'package:flutter/material.dart';

import 'theme.dart';

/// Rukhsa design-system tokens: spacing, radius, and type scale.
///
/// Everything in `screens/` and `widgets/` should pull numbers from here
/// rather than hard-coding paddings/sizes, so the app reads as one coherent
/// product instead of a pile of one-off screens.
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppRadii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

class AppType {
  static const display = TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 0.2);
  static const h1 = TextStyle(fontSize: 22, fontWeight: FontWeight.w800);
  static const h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.4);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
}

/// A rounded surface card used across the app for tappable list rows.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(AppSpacing.lg)});

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: EdgeInsets.zero,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
    return card;
  }
}

/// A small rounded badge/pill, e.g. for language codes or status tags.
class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? foreground;
  const AppBadge({super.key, required this.label, this.color, this.foreground});

  @override
  Widget build(BuildContext context) {
    final c = color ?? RukhsaColors.gold.withValues(alpha: 0.18);
    final fg = foreground ?? RukhsaColors.goldDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(label, style: AppType.caption.copyWith(color: fg)),
    );
  }
}

/// A tile representing a study category, icon + title + count + chevron.
class CategoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;
  const CategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? RukhsaColors.blue;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.h2, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: AppType.caption.copyWith(color: Theme.of(context).hintColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// A circular progress ring, used for mock-exam score and per-category
/// mastery. Value is 0..1.
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final Color color;
  final Color trackColor;
  final Widget? center;
  final double strokeWidth;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 84,
    this.color = RukhsaColors.gold,
    this.trackColor = const Color(0x22000000),
    this.center,
    this.strokeWidth = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(value: value.clamp(0, 1), color: color, trackColor: trackColor, strokeWidth: strokeWidth),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  _RingPainter({required this.value, required this.color, required this.trackColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90deg, start at top
      6.28319 * value,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.trackColor != trackColor;
}

/// A simple horizontal stat card used on the home screen dashboard row.
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const StatCard({super.key, required this.value, required this.label, required this.icon, this.color = RukhsaColors.blue});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: AppType.h1),
          Text(label, style: AppType.caption.copyWith(color: Theme.of(context).hintColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Empty/placeholder state used across screens that can have no data yet.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const AppEmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).hintColor),
            const SizedBox(height: AppSpacing.md),
            Text(text, textAlign: TextAlign.center, style: AppType.body.copyWith(color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }
}
