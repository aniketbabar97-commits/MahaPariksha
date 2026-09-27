import 'package:flutter/material.dart';

import '../core/app_icon.dart';
import '../core/app_scope.dart';
import '../core/design_system.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'home_screen.dart';

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

/// First-launch screen: pick a UI language before entering the app.
class LanguagePickerScreen extends StatelessWidget {
  const LanguagePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScopeProvider.of(context);
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: RukhsaColors.blue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const RukhsaWordmarkLockup(),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                t.chooseLanguageTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                t.chooseLanguageSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: supportedLanguages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final lang = supportedLanguages[i];
                    return _LanguageTile(
                      code: lang,
                      label: _languageNativeNames[lang] ?? lang,
                      onTap: () async {
                        await scope.setLanguage(lang);
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String code;
  final String label;
  final VoidCallback onTap;
  const _LanguageTile({required this.code, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
