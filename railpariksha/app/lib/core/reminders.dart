import 'notifications.dart';
import '../data/progress.dart';

/// Reschedules both reminders from the user's saved settings. Safe to call
/// often (on toggle, on time change, on launch) — cancels and re-adds.
Future<void> applyReminders(Progress p) async {
  await RailParikshaNotifications.cancelAll();
  if (!p.reminders) return;
  await RailParikshaNotifications.scheduleDaily(
    id: 1,
    hour: p.reminderHour,
    titleHi: 'आपका आज का Daily 10 तैयार है 🔥',
    bodyHi: 'सिर्फ 10 प्रश्न, 5 मिनट। चलिए अभ्यास शुरू करते हैं!',
  );
  final eveningHour = (p.reminderHour + 12) % 24;
  await RailParikshaNotifications.scheduleDaily(
    id: 2,
    hour: eveningHour == 0 ? 20 : eveningHour,
    titleHi: p.liveStreak > 0
        ? 'अपनी ${p.liveStreak} दिन की स्ट्रीक आज पूरी करें! 🔥'
        : 'आज थोड़ा अभ्यास कर लें? 💪',
    bodyHi: 'रोज़ थोड़ा, पर बिना नागा — यही सफलता का राज़ है।',
  );
}
