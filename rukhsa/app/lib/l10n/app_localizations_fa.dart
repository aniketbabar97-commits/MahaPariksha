// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'رخصه';

  @override
  String get tagline => 'آزمون رانندگی امارات';

  @override
  String get chooseLanguageTitle => 'زبان خود را انتخاب کنید';

  @override
  String get chooseLanguageSubtitle =>
      'می‌توانید این را در هر زمان از تنظیمات تغییر دهید';

  @override
  String get continueButton => 'ادامه';

  @override
  String get homeTitle => 'خانه';

  @override
  String get categoriesTitle => 'دسته‌بندی‌ها';

  @override
  String get startPractice => 'شروع تمرین';

  @override
  String questionsCount(int count) {
    return '$count سؤال';
  }

  @override
  String get needsVerificationBadge => 'در حال بررسی';

  @override
  String questionLabel(int current, int total) {
    return 'سؤال $current از $total';
  }

  @override
  String get showExplanation => 'نمایش توضیح';

  @override
  String get correctLabel => 'درست';

  @override
  String get incorrectLabel => 'نادرست';

  @override
  String get nextQuestion => 'بعدی';

  @override
  String get finishQuiz => 'پایان';

  @override
  String get retryQuiz => 'تلاش دوباره';

  @override
  String get backToHome => 'بازگشت به خانه';

  @override
  String get resultsTitle => 'نتایج';

  @override
  String get yourScore => 'امتیاز شما';

  @override
  String get passLabel => 'قبول';

  @override
  String get failLabel => 'هنوز نه - به تمرین ادامه دهید';

  @override
  String get passMarkNote =>
      'بیشتر مراکز RTA برای قبولی حدود ۶۰ تا ۷۰ درصد پاسخ درست می‌خواهند';

  @override
  String get settingsTitle => 'تنظیمات';

  @override
  String get languageSettings => 'زبان برنامه';

  @override
  String get aboutTitle => 'درباره رخصه';

  @override
  String get aboutBody =>
      'رخصه یک برنامه تمرین آفلاین برای آزمون تئوری رانندگی RTA امارات است. این یک ابزار مطالعه مستقل است و به هیچ نهاد دولتی وابسته نیست.';

  @override
  String get exitConfirmTitle => 'خروج از آزمون؟';

  @override
  String get exitConfirmBody => 'پیشرفت شما در این آزمون از بین می‌رود.';

  @override
  String get yes => 'بله';

  @override
  String get no => 'خیر';

  @override
  String get cancel => 'لغو';

  @override
  String get ok => 'باشه';

  @override
  String get practiceAllMistakes => 'بازبینی محتوای علامت‌گذاری‌شده';

  @override
  String get translationPendingNote =>
      'چون ترجمه این زبان هنوز در انتظار است، این متن به انگلیسی نمایش داده می‌شود.';
}
