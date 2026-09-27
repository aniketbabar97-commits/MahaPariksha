import 'package:flutter/material.dart';

/// Rukhsa brand: deep blue background with a gold (steering-wheel) accent,
/// matching the app icon/wordmark (blue field, gold wheel + road + car).
class RukhsaColors {
  static const blue = Color(0xFF0B2E63);
  static const blueDark = Color(0xFF071F45);
  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFE4C766);
  static const success = Color(0xFF1E8E3E);
  static const danger = Color(0xFFD93025);
}

ThemeData buildRukhsaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: RukhsaColors.blue,
    primary: RukhsaColors.blue,
    secondary: RukhsaColors.gold,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF6F7FB),
    appBarTheme: const AppBarTheme(
      backgroundColor: RukhsaColors.blue,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RukhsaColors.gold,
        foregroundColor: RukhsaColors.blueDark,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
    ),
  );
}
