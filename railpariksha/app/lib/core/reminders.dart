import 'notifications.dart';
import '../data/progress.dart';

/// Reschedules both reminders from the user's saved settings. Safe to call
/// often (on toggle, on time change, on launch) — cancels and re-adds.
String _tr(Progress p, String hi, String en) => p.lang == 'en' ? en : hi;

Future<void> applyReminders(Progress p) async {
  await RailParikshaNotifications.cancelAll();
  if (!p.reminders) return;
  await RailParikshaNotifications.scheduleDaily(
    id: 1,
    hour: p.reminderHour,
    title: _tr(p, 'आपका आज का Daily 10 तैयार है 🔥', "Your Daily 10 is ready 🔥"),
    body: _tr(p, 'सिर्फ 10 प्रश्न, 5 मिनट। चलिए अभ्यास शुरू करते हैं!', 'Just 10 questions, 5 minutes. Let\'s get started!'),
  );
  final eveningHour = (p.reminderHour + 12) % 24;
  await RailParikshaNotifications.scheduleDaily(
    id: 2,
    hour: eveningHour == 0 ? 20 : eveningHour,
    title: p.liveStreak > 0
        ? _tr(p, 'अपनी ${p.liveStreak} दिन की स्ट्रीक आज पूरी करें! 🔥', 'Keep your ${p.liveStreak}-day streak alive today! 🔥')
        : _tr(p, 'आज थोड़ा अभ्यास कर लें? 💪', 'A little practice today? 💪'),
    body: _tr(p, 'रोज़ थोड़ा, पर बिना नागा — यही सफलता का राज़ है।',
        'A little every day, without skipping — that\'s the real secret to success.'),
  );
}
