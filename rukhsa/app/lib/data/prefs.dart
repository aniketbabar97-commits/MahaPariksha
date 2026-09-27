import 'package:shared_preferences/shared_preferences.dart';

/// Small wrapper around SharedPreferences for the two pieces of state we
/// persist locally: the chosen UI language and whether onboarding was seen.
class Prefs {
  static const _kLang = 'rukhsa.lang';
  static const _kOnboarded = 'rukhsa.onboarded';

  static Future<String?> getLanguage() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLang);
  }

  static Future<void> setLanguage(String lang) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLang, lang);
    await sp.setBool(_kOnboarded, true);
  }

  static Future<bool> hasOnboarded() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kOnboarded) ?? false;
  }
}
