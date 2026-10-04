import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

/// Product analytics: which screens and ads students actually reach. Fire-and-forget and safe
/// anywhere -- it does nothing when Firebase isn't configured (tests, a build without
/// google-services.json), and a failed send is never allowed to surface.
///
/// Events carry no personal data: no name, no question text, only a mode/paper/count.
class Analytics {
  static void log(String event, [Map<String, Object>? params]) {
    try {
      if (Firebase.apps.isEmpty) return;
      FirebaseAnalytics.instance.logEvent(name: event, parameters: params).catchError((_) {});
    } catch (_) {
      // Analytics must never break the app.
    }
  }
}
