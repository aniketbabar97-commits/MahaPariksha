import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_scope.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/language_picker_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RukhsaApp());
}

class RukhsaApp extends StatefulWidget {
  const RukhsaApp({super.key});

  @override
  State<RukhsaApp> createState() => _RukhsaAppState();
}

class _RukhsaAppState extends State<RukhsaApp> {
  final AppScope _scope = AppScope();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _scope.addListener(_onScopeChanged);
    _scope.init().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _onScopeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scope.removeListener(_onScopeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return AppScopeProvider(
      scope: _scope,
      child: Builder(
        builder: (context) {
          final lang = _scope.lang;
          return MaterialApp(
            title: 'Rukhsa',
            debugShowCheckedModeBanner: false,
            theme: buildRukhsaTheme(),
            locale: Locale(lang),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supported) {
              if (locale != null &&
                  supported.any((l) => l.languageCode == locale.languageCode)) {
                return locale;
              }
              return const Locale('en');
            },
            builder: (context, child) {
              return Directionality(
                textDirection: directionFor(lang),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: _scope.onboarded ? const HomeScreen() : const LanguagePickerScreen(),
          );
        },
      ),
    );
  }
}
