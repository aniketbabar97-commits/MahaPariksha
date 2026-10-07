import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Play Store listing URL. Shared here (rather than on one screen) because
/// every share-to-a-friend message across the app needs it appended -- a
/// share message without a download link gives the recipient no way to
/// actually install the app, silently capping the value of every share.
const kPlayUrl = 'https://play.google.com/store/apps/details?id=app.railpariksha';

/// The RailPariksha Telegram channel, set at build time (--dart-define=TELEGRAM_URL=https://t.me/...). Empty hides
/// every "join our channel" prompt, so nothing dead ever shows before the channel exists.
const kTelegramUrl = String.fromEnvironment('TELEGRAM_URL');

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

  /// Text and icons on saffron/yellow surfaces: white there is barely readable (~1.6:1).
  static const onSaffron = Color(0xFF2B1D00);

  /// Plain `saffron` text on a light-mode white background is only ~1.9:1
  /// contrast -- WCAG AA needs 4.5:1 for normal-size text. Saffron itself
  /// stays the brand accent everywhere (icons, gradients, borders); this is
  /// only for the handful of places that render it as actual reading text.
  /// Already passes AA on the dark-mode navy Card background, so dark mode
  /// is untouched.
  /// Brand blue for text and icons. The deep navy [sky] is unreadable on dark-mode cards, so dark
  /// mode gets a lighter blue.
  static Color skyOn(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8DB0F5) : sky;

  static double _lum(Color c) {
    double lin(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
  }

  /// WCAG contrast ratio between two opaque colours.
  static double contrast(Color a, Color b) {
    final l1 = _lum(a), l2 = _lum(b);
    return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
  }

  /// Any accent colour (a subject colour, saffron, green...) used as TEXT or an ICON on a card or
  /// tinted tile: returned unchanged when it already reads on the current theme's surfaces,
  /// otherwise the same hue darkened (light theme) or lightened (dark theme) until it does.
  /// [min] is 4.5 for text and 3.0 for icons/large text (WCAG AA). Tiles are tinted with the
  /// colour itself, so the check runs against a slightly darker/lighter surface than the card.
  static Color readable(BuildContext context, Color c, {double min = 4.5}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (c == sky) return skyOn(context);
    final bg = dark ? const Color(0xFF1F2A44) : const Color(0xFFE4E9F2);
    var out = c;
    for (var i = 0; i < 20 && contrast(out, bg) < min; i++) {
      out = Color.lerp(out, dark ? Colors.white : Colors.black, 0.08)!;
    }
    return out;
  }

  /// Text/icon colour for something drawn ON a solid [fill]: whichever of white or the dark
  /// brand brown reads better (white on saffron is only ~1.8:1).
  static Color onFill(Color fill) => contrast(Colors.white, fill) >= contrast(onSaffron, fill) ? Colors.white : onSaffron;

  /// Secondary text on the blue brand gradients: white at 70% was ~4.1:1, this is ~6:1.
  static const onGradientMuted = Color(0xE6FFFFFF);

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
  /// Beast Mode card: deep red to burnt orange so white text clears 4.5:1 across the whole card
  /// (the old red-to-saffron ended at ~1.8:1 on the right).
  static const beastGradient = LinearGradient(
    colors: [Color(0xFFB3261E), Color(0xFFB84B08)],
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
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, fontFamily: 'Mukta', fontFamilyFallback: const ['MathFallback']);
  return base.copyWith(
    scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFEDF1F8) : const Color(0xFF0E1320),
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
        // Brand blue with white text in both themes (Material's seed-derived pale lavender looked
        // washed out on the dark background).
        backgroundColor: b == Brightness.light ? BrandColors.sky : BrandColors.skyLight,
        foregroundColor: Colors.white,
        disabledBackgroundColor: b == Brightness.light ? const Color(0xFFDDE3EF) : const Color(0xFF242C40),
        disabledForegroundColor: b == Brightness.light ? const Color(0xFF8A93A6) : const Color(0xFF6E7891),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: 'Mukta', fontFamilyFallback: ['MathFallback'], fontSize: 16, fontWeight: FontWeight.w700),
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

/// Per-topic icon for cards/headers that list many topics side by side
/// (cheat sheets, topic pickers) -- a single [subjectIcon] per subject
/// made every topic within it look identical; this gives each of the 91
/// distinct topic ids in taxonomy.json its own icon so cheat-sheet
/// categories and similar lists read as visually distinct at a glance,
/// not just color-coded. No raster image assets involved, same as
/// [subjectIcon] -- these are Material's built-in vector glyphs.
IconData topicIcon(String topicId) {
  const map = {
    // maths
    'number_system': Icons.pin,
    'hcf_lcm': Icons.join_full,
    'decimal_fraction': Icons.percent,
    'ratio_proportion': Icons.balance,
    'percentage': Icons.percent,
    'average': Icons.functions,
    'profit_loss': Icons.currency_rupee,
    'si_ci': Icons.account_balance,
    'time_work': Icons.engineering,
    'time_speed_distance': Icons.speed,
    'mensuration': Icons.square_foot,
    'algebra': Icons.functions,
    'geometry': Icons.change_history,
    'trigonometry': Icons.architecture,
    'data_interpretation': Icons.bar_chart,
    // reasoning
    'analogy': Icons.compare_arrows,
    'coding_decoding': Icons.key,
    'series': Icons.linear_scale,
    'classification': Icons.category,
    'blood_relations': Icons.family_restroom,
    'direction_sense': Icons.explore,
    'syllogism': Icons.account_tree,
    'statement_conclusion': Icons.fact_check,
    'puzzle_seating': Icons.event_seat,
    'alphabet_test': Icons.abc,
    'mirror_water_image': Icons.flip,
    'non_verbal_reasoning': Icons.extension,
    'mathematical_operations': Icons.calculate,
    // science
    'physics_basics': Icons.bolt,
    'chemistry_basics': Icons.science,
    'biology_basics': Icons.biotech,
    'human_body': Icons.accessibility_new,
    'everyday_science': Icons.lightbulb,
    'inventions_discoveries': Icons.emoji_objects,
    'physics_chemistry': Icons.science,
    'environment_pollution': Icons.eco,
    'engineering_basics': Icons.precision_manufacturing,
    // gk
    'indian_history': Icons.account_balance,
    'indian_polity': Icons.gavel,
    'indian_geography': Icons.terrain,
    'indian_economy': Icons.trending_up,
    'static_gk': Icons.public,
    'awards_honours': Icons.emoji_events,
    'books_authors': Icons.menu_book,
    'important_days': Icons.event,
    'sports_gk': Icons.sports_cricket,
    'environment_ecology': Icons.park,
    'indian_culture': Icons.temple_hindu,
    // railway_gk
    'railway_history': Icons.history_edu,
    'zones_divisions': Icons.map,
    'gauges_tracks': Icons.straighten,
    'trains_services': Icons.train,
    'safety_signalling': Icons.traffic,
    'railway_board_recruitment': Icons.badge,
    'railway_current_affairs': Icons.train_outlined,
    // computer
    'computer_fundamentals': Icons.computer,
    'ms_office': Icons.description,
    'internet_networking': Icons.wifi,
    'financial_awareness': Icons.currency_rupee,
    'cyber_security': Icons.security,
    // english
    'grammar': Icons.spellcheck,
    'vocabulary': Icons.translate,
    'comprehension': Icons.menu_book,
    'cloze_test': Icons.space_bar,
    'error_spotting': Icons.find_replace,
    // je_mechanical
    'thermodynamics': Icons.local_fire_department,
    'strength_of_materials': Icons.fitness_center,
    'fluid_mechanics_machinery': Icons.water,
    'manufacturing_processes': Icons.precision_manufacturing,
    'ic_engines_refrigeration': Icons.ac_unit,
    'engineering_mechanics': Icons.settings,
    // je_civil
    'building_materials': Icons.foundation,
    'surveying': Icons.explore,
    'structural_analysis': Icons.architecture,
    'soil_mechanics_foundation': Icons.layers,
    'transportation_engineering': Icons.directions_car,
    'environmental_engineering': Icons.water_drop,
    // je_electrical
    'circuit_theory': Icons.electrical_services,
    'electrical_machines': Icons.settings_input_component,
    'power_systems': Icons.bolt,
    'measurements_instrumentation': Icons.straighten,
    'control_systems': Icons.tune,
    'power_electronics': Icons.memory,
    // current_affairs
    'sports_news': Icons.sports_cricket,
    'awards_news': Icons.emoji_events_outlined,
    'schemes': Icons.account_balance_outlined,
    'appointments': Icons.badge_outlined,
    'sci_tech_news': Icons.science_outlined,
    'banking_finance': Icons.currency_rupee,
    'international': Icons.public,
    'national': Icons.flag,
  };
  return map[topicId] ?? Icons.menu_book;
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
