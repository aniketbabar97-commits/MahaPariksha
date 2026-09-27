import 'package:flutter/material.dart';

/// Rukhsa brand: deep blue background with a gold (steering-wheel) accent,
/// matching the app icon/wordmark (blue field, gold wheel + road + car).
///
/// Design-system note: this file is the single source of truth for color.
/// [AppSpacing], [AppRadii] and [AppTypography] in `design_system.dart` build
/// on top of these tokens for spacing/type/shape so every screen shares one
/// visual language instead of hard-coding numbers ad hoc.
class RukhsaColors {
  // Brand core (from the logo: blue field, gold steering wheel).
  static const blue = Color(0xFF0B2E63);
  static const blueDark = Color(0xFF071F45);
  static const blueLight = Color(0xFF1E4C8F);
  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFE4C766);
  static const goldDark = Color(0xFF8F701A);

  // Semantic.
  static const success = Color(0xFF1E8E3E);
  static const successDark = Color(0xFF6FCF8E);
  static const danger = Color(0xFFD93025);
  static const dangerDark = Color(0xFFFF8A80);
  static const warning = Color(0xFFF9A825);

  // Real UAE road-sign reference colors (used by the road-sign gallery).
  static const signRed = Color(0xFFD32F2F);
  static const signBlue = Color(0xFF0057A3);
  static const signYellow = Color(0xFFFDD835);
  static const signWhite = Color(0xFFFFFFFF);
  static const signBlack = Color(0xFF1A1A1A);
  static const signGreen = Color(0xFF1B7A3D);

  // Dark-mode surfaces.
  static const darkBg = Color(0xFF0A0E17);
  static const darkSurface = Color(0xFF151B2B);
  static const darkSurfaceAlt = Color(0xFF1E2740);

  static const heroGradient = LinearGradient(
    colors: [blueDark, blue, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [goldDark, gold, goldLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildRukhsaTheme([Brightness brightness = Brightness.light]) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: RukhsaColors.blue,
    primary: isDark ? RukhsaColors.blueLight : RukhsaColors.blue,
    secondary: RukhsaColors.gold,
    brightness: brightness,
    error: isDark ? RukhsaColors.dangerDark : RukhsaColors.danger,
  );

  final bg = isDark ? RukhsaColors.darkBg : const Color(0xFFF6F7FB);
  final surface = isDark ? RukhsaColors.darkSurface : Colors.white;
  final onSurface = isDark ? Colors.white.withValues(alpha: 0.92) : RukhsaColors.blueDark;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: onSurface,
          displayColor: onSurface,
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? RukhsaColors.darkSurface : RukhsaColors.blue,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
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
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? RukhsaColors.darkSurfaceAlt : RukhsaColors.blue.withValues(alpha: 0.06),
      labelStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w600, fontSize: 12),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: RukhsaColors.gold.withValues(alpha: 0.22),
      height: 66,
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: RukhsaColors.gold),
  );
}
