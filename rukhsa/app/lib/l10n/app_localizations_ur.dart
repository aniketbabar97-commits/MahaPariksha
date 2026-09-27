// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appTitle => 'رخصہ';

  @override
  String get tagline => 'یو اے ای ڈرائیونگ ٹیسٹ';

  @override
  String get chooseLanguageTitle => 'اپنی زبان منتخب کریں';

  @override
  String get chooseLanguageSubtitle =>
      'آپ اسے کبھی بھی ترتیبات میں تبدیل کر سکتے ہیں';

  @override
  String get continueButton => 'جاری رکھیں';

  @override
  String get homeTitle => 'ہوم';

  @override
  String get categoriesTitle => 'زمرہ جات';

  @override
  String get startPractice => 'مشق شروع کریں';

  @override
  String questionsCount(int count) {
    return '$count سوالات';
  }

  @override
  String get needsVerificationBadge => 'زیر جائزہ';

  @override
  String questionLabel(int current, int total) {
    return 'سوال $current از $total';
  }

  @override
  String get showExplanation => 'وضاحت دکھائیں';

  @override
  String get correctLabel => 'درست';

  @override
  String get incorrectLabel => 'غلط';

  @override
  String get nextQuestion => 'اگلا';

  @override
  String get finishQuiz => 'ختم کریں';

  @override
  String get retryQuiz => 'دوبارہ کوشش کریں';

  @override
  String get backToHome => 'ہوم پر واپس جائیں';

  @override
  String get resultsTitle => 'نتائج';

  @override
  String get yourScore => 'آپ کا اسکور';

  @override
  String get passLabel => 'پاس';

  @override
  String get failLabel => 'ابھی نہیں - مشق جاری رکھیں';

  @override
  String get passMarkNote =>
      'زیادہ تر آر ٹی اے مراکز پاس ہونے کے لیے تقریباً 60-70% درست جوابات کا تقاضا کرتے ہیں';

  @override
  String get settingsTitle => 'ترتیبات';

  @override
  String get languageSettings => 'ایپ کی زبان';

  @override
  String get aboutTitle => 'رخصہ کے بارے میں';

  @override
  String get aboutBody =>
      'رخصہ یو اے ای آر ٹی اے ڈرائیونگ تھیوری ٹیسٹ کے لیے ایک آف لائن پریکٹس ایپ ہے۔ یہ ایک آزاد مطالعاتی معاون ہے اور کسی سرکاری ادارے سے وابستہ نہیں۔';

  @override
  String get exitConfirmTitle => 'کوئز چھوڑیں؟';

  @override
  String get exitConfirmBody => 'اس کوئز میں آپ کی پیش رفت ضائع ہو جائے گی۔';

  @override
  String get yes => 'ہاں';

  @override
  String get no => 'نہیں';

  @override
  String get cancel => 'منسوخ کریں';

  @override
  String get ok => 'ٹھیک ہے';

  @override
  String get practiceAllMistakes => 'نشان شدہ مواد کا جائزہ لیں';

  @override
  String get translationPendingNote =>
      'یہ متن انگریزی میں دکھایا گیا ہے کیونکہ اس زبان کا ترجمہ ابھی زیر التوا ہے۔';
}
