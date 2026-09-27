import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_tl.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('bn'),
    Locale('en'),
    Locale('fa'),
    Locale('fr'),
    Locale('hi'),
    Locale('ml'),
    Locale('ru'),
    Locale('ta'),
    Locale('tl'),
    Locale('ur'),
    Locale('zh'),
  ];

  /// UI string: appTitle
  ///
  /// In en, this message translates to:
  /// **'Rukhsa'**
  String get appTitle;

  /// UI string: tagline
  ///
  /// In en, this message translates to:
  /// **'UAE Driving Test'**
  String get tagline;

  /// UI string: chooseLanguageTitle
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguageTitle;

  /// UI string: chooseLanguageSubtitle
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime in Settings'**
  String get chooseLanguageSubtitle;

  /// UI string: continueButton
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// UI string: homeTitle
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// UI string: categoriesTitle
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// UI string: startPractice
  ///
  /// In en, this message translates to:
  /// **'Start Practice'**
  String get startPractice;

  /// UI string: questionsCount
  ///
  /// In en, this message translates to:
  /// **'{count} questions'**
  String questionsCount(int count);

  /// UI string: needsVerificationBadge
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get needsVerificationBadge;

  /// UI string: questionLabel
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String questionLabel(int current, int total);

  /// UI string: showExplanation
  ///
  /// In en, this message translates to:
  /// **'Show explanation'**
  String get showExplanation;

  /// UI string: correctLabel
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correctLabel;

  /// UI string: incorrectLabel
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get incorrectLabel;

  /// UI string: nextQuestion
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextQuestion;

  /// UI string: finishQuiz
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finishQuiz;

  /// UI string: retryQuiz
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryQuiz;

  /// UI string: backToHome
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// UI string: resultsTitle
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get resultsTitle;

  /// UI string: yourScore
  ///
  /// In en, this message translates to:
  /// **'Your score'**
  String get yourScore;

  /// UI string: passLabel
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get passLabel;

  /// UI string: failLabel
  ///
  /// In en, this message translates to:
  /// **'Not yet - keep practicing'**
  String get failLabel;

  /// UI string: passMarkNote
  ///
  /// In en, this message translates to:
  /// **'Most RTA centres require about 60-70% correct to pass'**
  String get passMarkNote;

  /// UI string: settingsTitle
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// UI string: languageSettings
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageSettings;

  /// UI string: aboutTitle
  ///
  /// In en, this message translates to:
  /// **'About Rukhsa'**
  String get aboutTitle;

  /// UI string: aboutBody
  ///
  /// In en, this message translates to:
  /// **'Rukhsa is an offline practice app for the UAE RTA driving theory test. It is an independent study aid and is not affiliated with any government authority.'**
  String get aboutBody;

  /// UI string: exitConfirmTitle
  ///
  /// In en, this message translates to:
  /// **'Leave quiz?'**
  String get exitConfirmTitle;

  /// UI string: exitConfirmBody
  ///
  /// In en, this message translates to:
  /// **'Your progress in this quiz will be lost.'**
  String get exitConfirmBody;

  /// UI string: yes
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// UI string: no
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// UI string: cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// UI string: ok
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// UI string: practiceAllMistakes
  ///
  /// In en, this message translates to:
  /// **'Review flagged content'**
  String get practiceAllMistakes;

  /// UI string: translationPendingNote
  ///
  /// In en, this message translates to:
  /// **'This text is shown in English as this language\'s translation is still pending.'**
  String get translationPendingNote;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'bn',
    'en',
    'fa',
    'fr',
    'hi',
    'ml',
    'ru',
    'ta',
    'tl',
    'ur',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'ml':
      return AppLocalizationsMl();
    case 'ru':
      return AppLocalizationsRu();
    case 'ta':
      return AppLocalizationsTa();
    case 'tl':
      return AppLocalizationsTl();
    case 'ur':
      return AppLocalizationsUr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
