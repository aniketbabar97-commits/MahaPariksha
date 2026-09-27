// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'رخصة';

  @override
  String get tagline => 'اختبار القيادة في الإمارات';

  @override
  String get chooseLanguageTitle => 'اختر لغتك';

  @override
  String get chooseLanguageSubtitle => 'يمكنك تغيير هذا في أي وقت من الإعدادات';

  @override
  String get continueButton => 'متابعة';

  @override
  String get homeTitle => 'الرئيسية';

  @override
  String get categoriesTitle => 'الفئات';

  @override
  String get startPractice => 'ابدأ التدريب';

  @override
  String questionsCount(int count) {
    return '$count سؤال';
  }

  @override
  String get needsVerificationBadge => 'قيد المراجعة';

  @override
  String questionLabel(int current, int total) {
    return 'السؤال $current من $total';
  }

  @override
  String get showExplanation => 'إظهار الشرح';

  @override
  String get correctLabel => 'صحيح';

  @override
  String get incorrectLabel => 'غير صحيح';

  @override
  String get nextQuestion => 'التالي';

  @override
  String get finishQuiz => 'إنهاء';

  @override
  String get retryQuiz => 'إعادة المحاولة';

  @override
  String get backToHome => 'العودة للرئيسية';

  @override
  String get resultsTitle => 'النتائج';

  @override
  String get yourScore => 'نتيجتك';

  @override
  String get passLabel => 'ناجح';

  @override
  String get failLabel => 'ليس بعد - واصل التدريب';

  @override
  String get passMarkNote =>
      'تتطلب معظم مراكز هيئة الطرق والمواصلات حوالي 60-70% إجابات صحيحة للنجاح';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get languageSettings => 'لغة التطبيق';

  @override
  String get aboutTitle => 'حول رخصة';

  @override
  String get aboutBody =>
      'رخصة تطبيق تدريب غير متصل بالإنترنت لاختبار نظرية القيادة لدى هيئة الطرق والمواصلات في الإمارات. هذا التطبيق أداة دراسية مستقلة وغير تابع لأي جهة حكومية.';

  @override
  String get exitConfirmTitle => 'مغادرة الاختبار؟';

  @override
  String get exitConfirmBody => 'سيتم فقدان تقدمك في هذا الاختبار.';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get cancel => 'إلغاء';

  @override
  String get ok => 'موافق';

  @override
  String get practiceAllMistakes => 'مراجعة المحتوى المُعلَّم';

  @override
  String get translationPendingNote =>
      'يُعرض هذا النص بالإنجليزية لأن ترجمة هذه اللغة ما زالت قيد الإنجاز.';
}
