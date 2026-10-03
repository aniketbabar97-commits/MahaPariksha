import 'package:flutter/material.dart';

/// Play Store listing URL. Shared here (rather than on one screen) because
/// every share-to-a-friend message across the app needs it appended -- a
/// share message without a download link gives the recipient no way to
/// actually install the app, silently capping the value of every share.
const kPlayUrl = 'https://play.google.com/store/apps/details?id=app.railpariksha';

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

  /// Plain `saffron` text on a light-mode white background is only ~1.9:1
  /// contrast -- WCAG AA needs 4.5:1 for normal-size text. Saffron itself
  /// stays the brand accent everywhere (icons, gradients, borders); this is
  /// only for the handful of places that render it as actual reading text.
  /// Already passes AA on the dark-mode navy Card background, so dark mode
  /// is untouched.
  static Color saffronText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? const Color(0xFF9A6B00) : saffron;

  /// Android/iOS "Remove animations" accessibility setting -- for users with
  /// vestibular disorders/motion sensitivity, for whom things like a confetti
  /// burst of spinning falling pieces are a genuine discomfort trigger, not
  /// just a taste preference. Flutter does NOT auto-respect this system
  /// setting; every continuous/decorative animation has to check it itself.
  /// Scoped to the two most disruptive animations in the app (celebration
  /// confetti, the onboarding train's looping bob/smoke-puffs) rather than
  /// every transition -- a brief fade/slide between screens is not the kind
  /// of motion this setting exists to suppress.
  static bool reduceMotion(BuildContext context) => MediaQuery.of(context).disableAnimations;

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

// A phosphor_flutter-based duotone icon set was tried here and reverted --
// its PhosphorIconData extends IconData, which this Flutter SDK marks a
// `final class` (no external package may extend it), so release AOT
// compilation hard-fails even though `flutter analyze`/`test` both pass.
// Material's own *filled* glyphs (dropping the _outlined suffix) give a
// bolder, more deliberate look with zero dependency risk instead.
IconData subjectIcon(String name) {
  const map = {
    'translate': Icons.translate,
    'abc': Icons.abc,
    'calculate': Icons.calculate,
    'psychology': Icons.psychology,
    'account_balance': Icons.account_balance,
    'public': Icons.public,
    'gavel': Icons.gavel,
    'currency_rupee': Icons.currency_rupee,
    'science': Icons.science,
    'lightbulb': Icons.lightbulb,
    'computer': Icons.computer,
    'school': Icons.school,
    'traffic': Icons.traffic,
    'newspaper': Icons.newspaper,
    'eco': Icons.eco,
    'insights': Icons.insights,
    'park': Icons.park,
    'train': Icons.train,
    'build': Icons.build,
    'construction': Icons.construction,
    'bolt': Icons.bolt,
  };
  return map[name] ?? Icons.menu_book;
}
