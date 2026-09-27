import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../l10n/app_localizations.dart';

const Map<String, String> _languageNativeNames = {
  'en': 'English',
  'ar': 'العربية',
  'ur': 'اردو',
  'hi': 'हिन्दी',
  'tl': 'Tagalog',
  'ml': 'മലയാളം',
  'bn': 'বাংলা',
  'ta': 'தமிழ்',
  'fa': 'فارسی',
  'fr': 'Français',
  'zh': '中文',
  'ru': 'Русский',
};

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScopeProvider.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.settingsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(t.languageSettings, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final lang in supportedLanguages)
            RadioListTile<String>(
              value: lang,
              groupValue: scope.lang,
              title: Text(_languageNativeNames[lang] ?? lang),
              onChanged: (value) {
                if (value != null) scope.setLanguage(value);
              },
            ),
          const Divider(),
          ListTile(
            title: Text(t.aboutTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(t.aboutBody, style: const TextStyle(height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}
