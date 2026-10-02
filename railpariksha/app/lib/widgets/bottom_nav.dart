import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

class NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const NavItem(this.icon, this.selectedIcon, this.label);
}

/// A floating, rounded nav bar with a lifting-pill selection animation --
/// replaces the stock Material NavigationBar's flat indicator with something
/// that reads as a deliberate brand choice rather than a default.
class RpBottomNav extends StatelessWidget {
  final int index;
  final List<NavItem> items;
  final ValueChanged<int> onTap;
  const RpBottomNav({super.key, required this.index, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1A2133) : Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: (dark ? Colors.black : BrandColors.sky).withValues(alpha: dark ? 0.4 : 0.16),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < items.length; i++)
              _NavButton(
                // Stable, language-independent hook for the e2e test to find
                // and tap a specific tab -- this bar no longer uses stock
                // NavigationDestination widgets, which the test used to find
                // tabs by type.
                key: ValueKey('nav_tab_$i'),
                item: items[i],
                selected: i == index,
                onTap: () => _select(i),
              ),
          ],
        ),
      ),
    );
  }

  void _select(int i) {
    if (i != index) HapticFeedback.selectionClick();
    onTap(i);
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? BrandColors.saffron : Theme.of(context).hintColor;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 8),
            decoration: BoxDecoration(
              color: selected ? BrandColors.saffron.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              AnimatedScale(
                scale: selected ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.elasticOut,
                child: Icon(selected ? item.selectedIcon : item.icon, color: color, size: 24),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(item.label,
                            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5),
                            overflow: TextOverflow.ellipsis),
                      )
                    : const SizedBox(width: 0, height: 0),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
