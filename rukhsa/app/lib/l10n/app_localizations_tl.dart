// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tagalog (`tl`).
class AppLocalizationsTl extends AppLocalizations {
  AppLocalizationsTl([String locale = 'tl']) : super(locale);

  @override
  String get appTitle => 'Rukhsa';

  @override
  String get tagline => 'Pagsusulit sa Pagmamaneho ng UAE';

  @override
  String get chooseLanguageTitle => 'Pumili ng iyong wika';

  @override
  String get chooseLanguageSubtitle =>
      'Puwede mong baguhin ito anumang oras sa Mga Setting';

  @override
  String get continueButton => 'Magpatuloy';

  @override
  String get homeTitle => 'Home';

  @override
  String get categoriesTitle => 'Mga Kategorya';

  @override
  String get startPractice => 'Simulan ang Pagsasanay';

  @override
  String questionsCount(int count) {
    return '$count tanong';
  }

  @override
  String get needsVerificationBadge => 'Sinusuri pa';

  @override
  String questionLabel(int current, int total) {
    return 'Tanong $current ng $total';
  }

  @override
  String get showExplanation => 'Ipakita ang paliwanag';

  @override
  String get correctLabel => 'Tama';

  @override
  String get incorrectLabel => 'Mali';

  @override
  String get nextQuestion => 'Susunod';

  @override
  String get finishQuiz => 'Tapusin';

  @override
  String get retryQuiz => 'Subukan Muli';

  @override
  String get backToHome => 'Bumalik sa Home';

  @override
  String get resultsTitle => 'Mga Resulta';

  @override
  String get yourScore => 'Iyong iskor';

  @override
  String get passLabel => 'Pasado';

  @override
  String get failLabel => 'Hindi pa - magpatuloy sa pagsasanay';

  @override
  String get passMarkNote =>
      'Karamihan sa mga sentro ng RTA ay nangangailangan ng humigit-kumulang 60-70% tamang sagot para pumasa';

  @override
  String get settingsTitle => 'Mga Setting';

  @override
  String get languageSettings => 'Wika ng app';

  @override
  String get aboutTitle => 'Tungkol sa Rukhsa';

  @override
  String get aboutBody =>
      'Ang Rukhsa ay isang offline na app para sa pagsasanay sa UAE RTA driving theory test. Isa itong independiyenteng tulong sa pag-aaral at hindi kaakibat ng anumang ahensya ng pamahalaan.';

  @override
  String get exitConfirmTitle => 'Umalis sa pagsusulit?';

  @override
  String get exitConfirmBody =>
      'Mawawala ang iyong progreso sa pagsusulit na ito.';

  @override
  String get yes => 'Oo';

  @override
  String get no => 'Hindi';

  @override
  String get cancel => 'Kanselahin';

  @override
  String get ok => 'OK';

  @override
  String get practiceAllMistakes => 'Suriin ang mga naka-flag na nilalaman';

  @override
  String get translationPendingNote =>
      'Ipinapakita ang tekstong ito sa Ingles dahil nakabinbin pa ang pagsasalin sa wikang ito.';
}
