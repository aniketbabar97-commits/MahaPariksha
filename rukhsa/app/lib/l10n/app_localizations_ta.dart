// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'ருக்ஸா';

  @override
  String get tagline => 'யுஏஇ ஓட்டுநர் தேர்வு';

  @override
  String get chooseLanguageTitle => 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get chooseLanguageSubtitle =>
      'இதை அமைப்புகளில் எப்போது வேண்டுமானாலும் மாற்றலாம்';

  @override
  String get continueButton => 'தொடரவும்';

  @override
  String get homeTitle => 'முகப்பு';

  @override
  String get categoriesTitle => 'வகைகள்';

  @override
  String get startPractice => 'பயிற்சியைத் தொடங்கு';

  @override
  String questionsCount(int count) {
    return '$count கேள்விகள்';
  }

  @override
  String get needsVerificationBadge => 'மறுஆய்வில்';

  @override
  String questionLabel(int current, int total) {
    return 'கேள்வி $current / $total';
  }

  @override
  String get showExplanation => 'விளக்கத்தைக் காட்டு';

  @override
  String get correctLabel => 'சரி';

  @override
  String get incorrectLabel => 'தவறு';

  @override
  String get nextQuestion => 'அடுத்தது';

  @override
  String get finishQuiz => 'முடி';

  @override
  String get retryQuiz => 'மீண்டும் முயற்சி';

  @override
  String get backToHome => 'முகப்புக்குத் திரும்பு';

  @override
  String get resultsTitle => 'முடிவுகள்';

  @override
  String get yourScore => 'உங்கள் மதிப்பெண்';

  @override
  String get passLabel => 'தேர்ச்சி';

  @override
  String get failLabel => 'இன்னும் இல்லை - பயிற்சியைத் தொடரவும்';

  @override
  String get passMarkNote =>
      'பெரும்பாலான RTA மையங்கள் தேர்ச்சி பெற சுமார் 60-70% சரியான பதில்களை கோருகின்றன';

  @override
  String get settingsTitle => 'அமைப்புகள்';

  @override
  String get languageSettings => 'பயன்பாட்டு மொழி';

  @override
  String get aboutTitle => 'ருக்ஸா பற்றி';

  @override
  String get aboutBody =>
      'ருக்ஸா என்பது யுஏஇ ஆர்டிஏ ஓட்டுநர் தேற்று தேர்விற்கான ஆஃப்லைன் பயிற்சி பயன்பாடு. இது ஒரு சுயாதீன படிப்பு உதவியாகும், எந்த அரசு அமைப்புடனும் தொடர்பில்லை.';

  @override
  String get exitConfirmTitle => 'வினாடி வினாவை விட்டு வெளியேறவா?';

  @override
  String get exitConfirmBody =>
      'இந்த வினாடி வினாவில் உங்கள் முன்னேற்றம் இழக்கப்படும்.';

  @override
  String get yes => 'ஆம்';

  @override
  String get no => 'இல்லை';

  @override
  String get cancel => 'ரத்துசெய்';

  @override
  String get ok => 'சரி';

  @override
  String get practiceAllMistakes =>
      'கொடியிடப்பட்ட உள்ளடக்கத்தை மறுஆய்வு செய்யவும்';

  @override
  String get translationPendingNote =>
      'இந்த மொழியின் மொழிபெயர்ப்பு இன்னும் நிலுவையில் இருப்பதால் இந்த உரை ஆங்கிலத்தில் காட்டப்படுகிறது.';
}
