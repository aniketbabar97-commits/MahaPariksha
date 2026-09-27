// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Rukhsa';

  @override
  String get tagline => 'Examen de conduite aux Émirats';

  @override
  String get chooseLanguageTitle => 'Choisissez votre langue';

  @override
  String get chooseLanguageSubtitle =>
      'Vous pouvez modifier ceci à tout moment dans les paramètres';

  @override
  String get continueButton => 'Continuer';

  @override
  String get homeTitle => 'Accueil';

  @override
  String get categoriesTitle => 'Catégories';

  @override
  String get startPractice => 'Commencer l\'entraînement';

  @override
  String questionsCount(int count) {
    return '$count questions';
  }

  @override
  String get needsVerificationBadge => 'En cours de vérification';

  @override
  String questionLabel(int current, int total) {
    return 'Question $current sur $total';
  }

  @override
  String get showExplanation => 'Afficher l\'explication';

  @override
  String get correctLabel => 'Correct';

  @override
  String get incorrectLabel => 'Incorrect';

  @override
  String get nextQuestion => 'Suivant';

  @override
  String get finishQuiz => 'Terminer';

  @override
  String get retryQuiz => 'Réessayer';

  @override
  String get backToHome => 'Retour à l\'accueil';

  @override
  String get resultsTitle => 'Résultats';

  @override
  String get yourScore => 'Votre score';

  @override
  String get passLabel => 'Réussi';

  @override
  String get failLabel => 'Pas encore - continuez à vous entraîner';

  @override
  String get passMarkNote =>
      'La plupart des centres RTA exigent environ 60 à 70 % de bonnes réponses pour réussir';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get languageSettings => 'Langue de l\'application';

  @override
  String get aboutTitle => 'À propos de Rukhsa';

  @override
  String get aboutBody =>
      'Rukhsa est une application d\'entraînement hors ligne pour l\'examen théorique de conduite de la RTA des Émirats. C\'est un outil d\'étude indépendant, non affilié à une autorité gouvernementale.';

  @override
  String get exitConfirmTitle => 'Quitter le quiz ?';

  @override
  String get exitConfirmBody => 'Votre progression dans ce quiz sera perdue.';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get cancel => 'Annuler';

  @override
  String get ok => 'OK';

  @override
  String get practiceAllMistakes => 'Revoir le contenu signalé';

  @override
  String get translationPendingNote =>
      'Ce texte est affiché en anglais car la traduction dans cette langue est encore en attente.';
}
