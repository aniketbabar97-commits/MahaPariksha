import 'package:flutter/material.dart';

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
      elevation: 0,
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

IconData subjectIcon(String name) {
  const map = {
    'translate': Icons.translate,
    'abc': Icons.abc,
    'calculate': Icons.calculate_outlined,
    'psychology': Icons.psychology_outlined,
    'account_balance': Icons.account_balance_outlined,
    'public': Icons.public,
    'gavel': Icons.gavel_outlined,
    'currency_rupee': Icons.currency_rupee,
    'science': Icons.science_outlined,
    'lightbulb': Icons.lightbulb_outline,
    'computer': Icons.computer,
    'school': Icons.school_outlined,
    'traffic': Icons.traffic_outlined,
    'newspaper': Icons.newspaper,
    'eco': Icons.eco_outlined,
    'insights': Icons.insights,
    'park': Icons.park_outlined,
    'train': Icons.train_outlined,
    'build': Icons.build_outlined,
    'construction': Icons.construction_outlined,
    'bolt': Icons.bolt,
  };
  return map[name] ?? Icons.menu_book_outlined;
}
