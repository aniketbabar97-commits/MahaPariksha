import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shared spacing scale so padding/gaps stay consistent instead of scattering
/// magic numbers across screens. Use these for new/updated layout code.
class Spacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

/// Shared corner-radius scale, matching the values already used by the
/// card/button themes below.
class Corners {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 28.0;
}

/// Minimum recommended tap target size (Material accessibility guideline).
const double kMinTapTarget = 48.0;

class BrandColors {
  static const sky = Color(0xFF0B3D91);
  static const skyLight = Color(0xFF3A6FD8);
  static const saffron = Color(0xFFF5B400);
  static const sunrise = Color(0xFFFFD166);
  static const correct = Color(0xFF1E9E5A);
  static const wrong = Color(0xFFD64545);

  static const heroGradient = LinearGradient(
    colors: [sky, skyLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const fireGradient = LinearGradient(
    colors: [saffron, sunrise],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.sky,
    brightness: b,
    secondary: BrandColors.saffron,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, fontFamily: 'Mukta');
  return base.copyWith(
    scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF5F7FC) : const Color(0xFF0E1320),
    cardTheme: CardThemeData(
      // A flat elevation:0 made every card and the content behind it blur
      // into one plane -- a soft colored shadow (sky-tinted, not pure black)
      // reads as a deliberate depth system instead of Material's defaults.
      // Dark mode keeps it flat since a shadow barely registers against the
      // near-black background there and would mostly look like banding.
      elevation: b == Brightness.light ? 3 : 0,
      shadowColor: BrandColors.sky.withValues(alpha: b == Brightness.light ? 0.16 : 0),
      surfaceTintColor: Colors.transparent,
      color: b == Brightness.light ? Colors.white : const Color(0xFF1A2133),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: 'Mukta', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      indicatorColor: BrandColors.saffron.withValues(alpha: 0.22),
      labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
    ),
  );
}

// Phosphor's filled glyphs read as a deliberate, branded icon set at a
// glance instead of stock Material outlines -- every one of these names was
// confirmed against the phosphor_flutter 2.1.0 package source before use.
IconData subjectIcon(String name) {
  const map = {
    'translate': Icons.translate,
    'abc': PhosphorIcons.textAa(PhosphorIconsStyle.fill),
    'calculate': PhosphorIcons.calculator(PhosphorIconsStyle.fill),
    'psychology': PhosphorIcons.brain(PhosphorIconsStyle.fill),
    'account_balance': Icons.account_balance_outlined,
    'public': PhosphorIcons.globe(PhosphorIconsStyle.fill),
    'gavel': Icons.gavel_outlined,
    'currency_rupee': Icons.currency_rupee,
    'science': PhosphorIcons.flask(PhosphorIconsStyle.fill),
    'lightbulb': Icons.lightbulb_outline,
    'computer': PhosphorIcons.desktop(PhosphorIconsStyle.fill),
    'school': Icons.school_outlined,
    'traffic': Icons.traffic_outlined,
    'newspaper': PhosphorIcons.newspaper(PhosphorIconsStyle.fill),
    'eco': Icons.eco_outlined,
    'insights': Icons.insights,
    'park': Icons.park_outlined,
    'train': PhosphorIcons.trainSimple(PhosphorIconsStyle.fill),
    'build': PhosphorIcons.wrench(PhosphorIconsStyle.fill),
    'construction': PhosphorIcons.hardHat(PhosphorIconsStyle.fill),
    'bolt': PhosphorIcons.lightning(PhosphorIconsStyle.fill),
  };
  return map[name] ?? Icons.menu_book_outlined;
}
