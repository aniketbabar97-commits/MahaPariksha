// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'रुखसा';

  @override
  String get tagline => 'यूएई ड्राइविंग टेस्ट';

  @override
  String get chooseLanguageTitle => 'अपनी भाषा चुनें';

  @override
  String get chooseLanguageSubtitle =>
      'आप इसे कभी भी सेटिंग्स में बदल सकते हैं';

  @override
  String get continueButton => 'जारी रखें';

  @override
  String get homeTitle => 'होम';

  @override
  String get categoriesTitle => 'श्रेणियाँ';

  @override
  String get startPractice => 'अभ्यास शुरू करें';

  @override
  String questionsCount(int count) {
    return '$count प्रश्न';
  }

  @override
  String get needsVerificationBadge => 'समीक्षाधीन';

  @override
  String questionLabel(int current, int total) {
    return 'प्रश्न $current / $total';
  }

  @override
  String get showExplanation => 'व्याख्या दिखाएं';

  @override
  String get correctLabel => 'सही';

  @override
  String get incorrectLabel => 'गलत';

  @override
  String get nextQuestion => 'अगला';

  @override
  String get finishQuiz => 'समाप्त करें';

  @override
  String get retryQuiz => 'पुनः प्रयास करें';

  @override
  String get backToHome => 'होम पर वापस जाएं';

  @override
  String get resultsTitle => 'परिणाम';

  @override
  String get yourScore => 'आपका स्कोर';

  @override
  String get passLabel => 'उत्तीर्ण';

  @override
  String get failLabel => 'अभी नहीं - अभ्यास जारी रखें';

  @override
  String get passMarkNote =>
      'अधिकांश आरटीए केंद्रों में उत्तीर्ण होने के लिए लगभग 60-70% सही उत्तर चाहिए';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get languageSettings => 'ऐप की भाषा';

  @override
  String get aboutTitle => 'रुखसा के बारे में';

  @override
  String get aboutBody =>
      'रुखसा यूएई आरटीए ड्राइविंग थ्योरी टेस्ट के लिए एक ऑफलाइन अभ्यास ऐप है। यह एक स्वतंत्र अध्ययन सहायक है और किसी सरकारी प्राधिकरण से संबद्ध नहीं है।';

  @override
  String get exitConfirmTitle => 'क्विज़ छोड़ें?';

  @override
  String get exitConfirmBody => 'इस क्विज़ में आपकी प्रगति खो जाएगी।';

  @override
  String get yes => 'हां';

  @override
  String get no => 'नहीं';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get ok => 'ठीक है';

  @override
  String get practiceAllMistakes => 'फ़्लैग की गई सामग्री की समीक्षा करें';

  @override
  String get translationPendingNote =>
      'यह पाठ अंग्रेज़ी में दिखाया गया है क्योंकि इस भाषा का अनुवाद अभी लंबित है।';
}
