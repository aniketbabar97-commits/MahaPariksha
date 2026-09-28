import 'package:flutter/widgets.dart';

import '../data/content_repo.dart';
import '../data/progress.dart';
import '../logic/quiz_builder.dart';

class AppScope extends InheritedNotifier<Progress> {
  final ContentRepo repo;
  final QuizBuilder builder;

  AppScope({super.key, required this.repo, required Progress progress, required super.child})
      : builder = QuizBuilder(repo, progress),
        super(notifier: progress);

  Progress get progress => notifier!;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  static AppScope read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;
}

extension ScopeX on BuildContext {
  AppScope get scope => AppScope.of(this);
  String get lang => AppScope.of(this).progress.lang;

  /// Pick the Hindi or English string for the current language.
  String tr(String hi, String en) => lang == 'en' ? en : hi;
}
