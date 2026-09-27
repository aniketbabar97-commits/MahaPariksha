// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malayalam (`ml`).
class AppLocalizationsMl extends AppLocalizations {
  AppLocalizationsMl([String locale = 'ml']) : super(locale);

  @override
  String get appTitle => 'റുഖ്സ';

  @override
  String get tagline => 'യുഎഇ ഡ്രൈവിംഗ് ടെസ്റ്റ്';

  @override
  String get chooseLanguageTitle => 'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക';

  @override
  String get chooseLanguageSubtitle =>
      'സെറ്റിംഗ്സിൽ ഇത് എപ്പോൾ വേണമെങ്കിലും മാറ്റാം';

  @override
  String get continueButton => 'തുടരുക';

  @override
  String get homeTitle => 'ഹോം';

  @override
  String get categoriesTitle => 'വിഭാഗങ്ങൾ';

  @override
  String get startPractice => 'പരിശീലനം ആരംഭിക്കുക';

  @override
  String questionsCount(int count) {
    return '$count ചോദ്യങ്ങൾ';
  }

  @override
  String get needsVerificationBadge => 'അവലോകനത്തിലാണ്';

  @override
  String questionLabel(int current, int total) {
    return 'ചോദ്യം $current / $total';
  }

  @override
  String get showExplanation => 'വിശദീകരണം കാണിക്കുക';

  @override
  String get correctLabel => 'ശരി';

  @override
  String get incorrectLabel => 'തെറ്റ്';

  @override
  String get nextQuestion => 'അടുത്തത്';

  @override
  String get finishQuiz => 'പൂർത്തിയാക്കുക';

  @override
  String get retryQuiz => 'വീണ്ടും ശ്രമിക്കുക';

  @override
  String get backToHome => 'ഹോമിലേക്ക് മടങ്ങുക';

  @override
  String get resultsTitle => 'ഫലങ്ങൾ';

  @override
  String get yourScore => 'നിങ്ങളുടെ സ്കോർ';

  @override
  String get passLabel => 'പാസ്';

  @override
  String get failLabel => 'ഇതുവരെ ഇല്ല - പരിശീലനം തുടരുക';

  @override
  String get passMarkNote =>
      'മിക്ക ആർടിഎ കേന്ദ്രങ്ങളും പാസാകാൻ ഏകദേശം 60-70% ശരി ഉത്തരങ്ങൾ ആവശ്യപ്പെടുന്നു';

  @override
  String get settingsTitle => 'ക്രമീകരണങ്ങൾ';

  @override
  String get languageSettings => 'ആപ്പ് ഭാഷ';

  @override
  String get aboutTitle => 'റുഖ്സയെക്കുറിച്ച്';

  @override
  String get aboutBody =>
      'യുഎഇ ആർടിഎ ഡ്രൈവിംഗ് തിയറി ടെസ്റ്റിനുള്ള ഓഫ്‌ലൈൻ പരിശീലന ആപ്പാണ് റുഖ്സ. ഇത് ഒരു സ്വതന്ത്ര പഠന സഹായിയാണ്, ഏതെങ്കിലും സർക്കാർ അതോറിറ്റിയുമായി ബന്ധമില്ല.';

  @override
  String get exitConfirmTitle => 'ക്വിസ് വിടണോ?';

  @override
  String get exitConfirmBody => 'ഈ ക്വിസിലെ നിങ്ങളുടെ പുരോഗതി നഷ്ടപ്പെടും.';

  @override
  String get yes => 'അതെ';

  @override
  String get no => 'ഇല്ല';

  @override
  String get cancel => 'റദ്ദാക്കുക';

  @override
  String get ok => 'ശരി';

  @override
  String get practiceAllMistakes =>
      'അടയാളപ്പെടുത്തിയ ഉള്ളടക്കം അവലോകനം ചെയ്യുക';

  @override
  String get translationPendingNote =>
      'ഈ ഭാഷയുടെ പരിഭാഷ ഇനിയും തീരുമാനമായിട്ടില്ലാത്തതിനാൽ ഈ വാചകം ഇംഗ്ലീഷിൽ കാണിക്കുന്നു.';
}
