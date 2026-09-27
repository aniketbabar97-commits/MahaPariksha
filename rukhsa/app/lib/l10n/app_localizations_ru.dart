// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Rukhsa';

  @override
  String get tagline => 'Экзамен по вождению в ОАЭ';

  @override
  String get chooseLanguageTitle => 'Выберите ваш язык';

  @override
  String get chooseLanguageSubtitle =>
      'Вы можете изменить это в любое время в настройках';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get homeTitle => 'Главная';

  @override
  String get categoriesTitle => 'Категории';

  @override
  String get startPractice => 'Начать практику';

  @override
  String questionsCount(int count) {
    return '$count вопросов';
  }

  @override
  String get needsVerificationBadge => 'На проверке';

  @override
  String questionLabel(int current, int total) {
    return 'Вопрос $current из $total';
  }

  @override
  String get showExplanation => 'Показать объяснение';

  @override
  String get correctLabel => 'Правильно';

  @override
  String get incorrectLabel => 'Неправильно';

  @override
  String get nextQuestion => 'Далее';

  @override
  String get finishQuiz => 'Завершить';

  @override
  String get retryQuiz => 'Повторить';

  @override
  String get backToHome => 'На главную';

  @override
  String get resultsTitle => 'Результаты';

  @override
  String get yourScore => 'Ваш результат';

  @override
  String get passLabel => 'Сдано';

  @override
  String get failLabel => 'Пока нет - продолжайте практиковаться';

  @override
  String get passMarkNote =>
      'Большинству центров RTA требуется около 60-70% правильных ответов для сдачи';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get languageSettings => 'Язык приложения';

  @override
  String get aboutTitle => 'О приложении Rukhsa';

  @override
  String get aboutBody =>
      'Rukhsa - это офлайн-приложение для подготовки к теоретическому экзамену по вождению RTA в ОАЭ. Это независимое учебное пособие, не связанное с какими-либо государственными органами.';

  @override
  String get exitConfirmTitle => 'Покинуть тест?';

  @override
  String get exitConfirmBody => 'Ваш прогресс в этом тесте будет потерян.';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get cancel => 'Отмена';

  @override
  String get ok => 'ОК';

  @override
  String get practiceAllMistakes => 'Повторить отмеченные материалы';

  @override
  String get translationPendingNote =>
      'Этот текст отображается на английском языке, так как перевод на этот язык пока не завершён.';
}
