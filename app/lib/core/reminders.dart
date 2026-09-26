import 'notifications.dart';
import '../data/progress.dart';

/// Reschedules both reminders from the user's saved settings. Safe to call
/// often (on toggle, on time change, on launch) — cancels and re-adds.
Future<void> applyReminders(Progress p) async {
  await BharariNotifications.cancelAll();
  if (!p.reminders) return;
  await BharariNotifications.scheduleDaily(
    id: 1,
    hour: p.reminderHour,
    titleMr: 'तुमचं आजचं Daily 10 तयार आहे 🔥',
    bodyMr: 'फक्त 10 प्रश्न, 5 मिनिटं. चला भरारी घेऊया!',
  );
  final eveningHour = (p.reminderHour + 12) % 24;
  await BharariNotifications.scheduleDaily(
    id: 2,
    hour: eveningHour == 0 ? 20 : eveningHour,
    titleMr: p.liveStreak > 0
        ? 'तुमचा ${p.liveStreak} दिवसांचा स्ट्रीक आज पूर्ण करा! 🔥'
        : 'आज थोडा अभ्यास करूया का? 💪',
    bodyMr: 'रोज थोडं, पण न चुकता — हेच यशाचं गुपित.',
  );
}
