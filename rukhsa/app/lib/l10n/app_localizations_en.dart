// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Rukhsa';

  @override
  String get tagline => 'UAE Driving Test';

  @override
  String get chooseLanguageTitle => 'Choose your language';

  @override
  String get chooseLanguageSubtitle =>
      'You can change this anytime in Settings';

  @override
  String get continueButton => 'Continue';

  @override
  String get homeTitle => 'Home';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get startPractice => 'Start Practice';

  @override
  String questionsCount(int count) {
    return '$count questions';
  }

  @override
  String get needsVerificationBadge => 'Under review';

  @override
  String questionLabel(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get showExplanation => 'Show explanation';

  @override
  String get correctLabel => 'Correct';

  @override
  String get incorrectLabel => 'Incorrect';

  @override
  String get nextQuestion => 'Next';

  @override
  String get finishQuiz => 'Finish';

  @override
  String get retryQuiz => 'Retry';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get resultsTitle => 'Results';

  @override
  String get yourScore => 'Your score';

  @override
  String get passLabel => 'Pass';

  @override
  String get failLabel => 'Not yet - keep practicing';

  @override
  String get passMarkNote =>
      'Most RTA centres require about 60-70% correct to pass';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageSettings => 'App language';

  @override
  String get aboutTitle => 'About Rukhsa';

  @override
  String get aboutBody =>
      'Rukhsa is an offline practice app for the UAE RTA driving theory test. It is an independent study aid and is not affiliated with any government authority.';

  @override
  String get exitConfirmTitle => 'Leave quiz?';

  @override
  String get exitConfirmBody => 'Your progress in this quiz will be lost.';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get practiceAllMistakes => 'Review flagged content';

  @override
  String get translationPendingNote =>
      'This text is shown in English as this language\'s translation is still pending.';
}
