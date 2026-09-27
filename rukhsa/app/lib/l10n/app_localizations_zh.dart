// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Rukhsa';

  @override
  String get tagline => '阿联酋驾驶考试';

  @override
  String get chooseLanguageTitle => '选择您的语言';

  @override
  String get chooseLanguageSubtitle => '您可以随时在设置中更改此项';

  @override
  String get continueButton => '继续';

  @override
  String get homeTitle => '首页';

  @override
  String get categoriesTitle => '分类';

  @override
  String get startPractice => '开始练习';

  @override
  String questionsCount(int count) {
    return '$count 道题';
  }

  @override
  String get needsVerificationBadge => '审核中';

  @override
  String questionLabel(int current, int total) {
    return '第 $current 题,共 $total 题';
  }

  @override
  String get showExplanation => '显示解析';

  @override
  String get correctLabel => '正确';

  @override
  String get incorrectLabel => '错误';

  @override
  String get nextQuestion => '下一题';

  @override
  String get finishQuiz => '完成';

  @override
  String get retryQuiz => '重试';

  @override
  String get backToHome => '返回首页';

  @override
  String get resultsTitle => '结果';

  @override
  String get yourScore => '您的得分';

  @override
  String get passLabel => '通过';

  @override
  String get failLabel => '还未通过 - 继续练习';

  @override
  String get passMarkNote => '大多数RTA考试中心要求答对约60-70%才能通过';

  @override
  String get settingsTitle => '设置';

  @override
  String get languageSettings => '应用语言';

  @override
  String get aboutTitle => '关于 Rukhsa';

  @override
  String get aboutBody =>
      'Rukhsa 是一款用于阿联酋RTA驾驶理论考试的离线练习应用。它是一个独立的学习辅助工具,与任何政府机构均无关联。';

  @override
  String get exitConfirmTitle => '退出测验?';

  @override
  String get exitConfirmBody => '您在本次测验中的进度将会丢失。';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get cancel => '取消';

  @override
  String get ok => '确定';

  @override
  String get practiceAllMistakes => '复习标记内容';

  @override
  String get translationPendingNote => '由于该语言的翻译尚未完成,此文本以英文显示。';
}
