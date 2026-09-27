// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'রুখসা';

  @override
  String get tagline => 'ইউএই ড্রাইভিং টেস্ট';

  @override
  String get chooseLanguageTitle => 'আপনার ভাষা নির্বাচন করুন';

  @override
  String get chooseLanguageSubtitle =>
      'আপনি এটি যেকোনো সময় সেটিংসে পরিবর্তন করতে পারেন';

  @override
  String get continueButton => 'চালিয়ে যান';

  @override
  String get homeTitle => 'হোম';

  @override
  String get categoriesTitle => 'বিভাগসমূহ';

  @override
  String get startPractice => 'অনুশীলন শুরু করুন';

  @override
  String questionsCount(int count) {
    return '$countটি প্রশ্ন';
  }

  @override
  String get needsVerificationBadge => 'পর্যালোচনাধীন';

  @override
  String questionLabel(int current, int total) {
    return 'প্রশ্ন $current এর $total';
  }

  @override
  String get showExplanation => 'ব্যাখ্যা দেখান';

  @override
  String get correctLabel => 'সঠিক';

  @override
  String get incorrectLabel => 'ভুল';

  @override
  String get nextQuestion => 'পরবর্তী';

  @override
  String get finishQuiz => 'সমাপ্ত করুন';

  @override
  String get retryQuiz => 'আবার চেষ্টা করুন';

  @override
  String get backToHome => 'হোমে ফিরে যান';

  @override
  String get resultsTitle => 'ফলাফল';

  @override
  String get yourScore => 'আপনার স্কোর';

  @override
  String get passLabel => 'উত্তীর্ণ';

  @override
  String get failLabel => 'এখনও না - অনুশীলন চালিয়ে যান';

  @override
  String get passMarkNote =>
      'বেশিরভাগ আরটিএ কেন্দ্রে পাস করতে প্রায় ৬০-৭০% সঠিক উত্তর প্রয়োজন';

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get languageSettings => 'অ্যাপের ভাষা';

  @override
  String get aboutTitle => 'রুখসা সম্পর্কে';

  @override
  String get aboutBody =>
      'রুখসা ইউএই আরটিএ ড্রাইভিং তত্ত্ব পরীক্ষার জন্য একটি অফলাইন অনুশীলন অ্যাপ। এটি একটি স্বাধীন অধ্যয়ন সহায়ক এবং কোনো সরকারি কর্তৃপক্ষের সাথে সংযুক্ত নয়।';

  @override
  String get exitConfirmTitle => 'কুইজ ছাড়বেন?';

  @override
  String get exitConfirmBody => 'এই কুইজে আপনার অগ্রগতি হারিয়ে যাবে।';

  @override
  String get yes => 'হ্যাঁ';

  @override
  String get no => 'না';

  @override
  String get cancel => 'বাতিল করুন';

  @override
  String get ok => 'ঠিক আছে';

  @override
  String get practiceAllMistakes => 'চিহ্নিত সামগ্রী পর্যালোচনা করুন';

  @override
  String get translationPendingNote =>
      'এই ভাষার অনুবাদ এখনও মুলতুবি থাকায় এই টেক্সটি ইংরেজিতে দেখানো হচ্ছে।';
}
