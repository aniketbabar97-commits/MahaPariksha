import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Small wrapper around SharedPreferences for local state: chosen UI
/// language, onboarding, flashcard spaced-repetition state, and the
/// emirate/vehicle-type study filters.
class Prefs {
  static const _kLang = 'rukhsa.lang';
  static const _kOnboarded = 'rukhsa.onboarded';
  static const _kFlashcardState = 'rukhsa.flashcards.state.v1';
  static const _kEmirate = 'rukhsa.filter.emirate';
  static const _kVehicleType = 'rukhsa.filter.vehicleType';

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

  /// Flashcard SM-2-lite scheduler state, keyed by question id. Each entry:
  /// {"reps": int, "interval": int (days), "ease": double, "due": ISO8601}.
  static Future<Map<String, dynamic>> getFlashcardState() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kFlashcardState);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> setFlashcardState(Map<String, dynamic> state) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kFlashcardState, jsonEncode(state));
  }

  static Future<String> getEmirate() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kEmirate) ?? 'all';
  }

  static Future<void> setEmirate(String value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kEmirate, value);
  }

  static Future<String> getVehicleType() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kVehicleType) ?? 'car';
  }

  static Future<void> setVehicleType(String value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kVehicleType, value);
  }
}
