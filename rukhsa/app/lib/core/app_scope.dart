import 'package:flutter/material.dart';

import '../data/content_repo.dart';
import '../data/models.dart';
import '../data/prefs.dart';

/// RTL languages get right-to-left text direction; the rest are LTR.
const List<String> rtlLanguages = ['ar', 'ur', 'fa'];

const List<String> supportedLanguages = [
  'en', 'ar', 'ur', 'hi', 'tl', 'ml', 'bn', 'ta', 'fa', 'fr', 'zh', 'ru',
];

TextDirection directionFor(String lang) =>
    rtlLanguages.contains(lang) ? TextDirection.rtl : TextDirection.ltr;

/// App-wide mutable state: current language + loaded content bundle.
class AppScope extends ChangeNotifier {
  final ContentRepo _repo = ContentRepo();

  String _lang = 'en';
  ContentBundle? _bundle;
  bool _onboarded = false;

  String get lang => _lang;
  ContentBundle? get bundle => _bundle;
  bool get onboarded => _onboarded;
  bool get isLoaded => _bundle != null;

  Future<void> init() async {
    final savedLang = await Prefs.getLanguage();
    _onboarded = await Prefs.hasOnboarded();
    if (savedLang != null) _lang = savedLang;
    _bundle = await _repo.load();
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _lang = lang;
    _onboarded = true;
    await Prefs.setLanguage(lang);
    notifyListeners();
  }
}

class AppScopeProvider extends InheritedNotifier<AppScope> {
  const AppScopeProvider({super.key, required AppScope scope, required super.child})
      : super(notifier: scope);

  static AppScope of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppScopeProvider>();
    assert(provider != null, 'AppScopeProvider not found in context');
    return provider!.notifier!;
  }
}
