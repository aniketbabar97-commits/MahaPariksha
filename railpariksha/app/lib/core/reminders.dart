import 'notifications.dart';
import '../data/progress.dart';

/// Reschedules both reminders from the user's saved settings. Safe to call
/// often (on toggle, on time change, on launch) — cancels and re-adds.
///
/// Message content is re-derived from current state every call, so each
/// day's ping surfaces whichever signal is actually most likely to bring
/// the user back today: an imminent exam beats everything (it's a real
/// deadline), then a streak about to break (loss aversion is the strongest
/// lever once a streak exists), then a backlog of unreviewed mistakes, and
/// only then a generic nudge for a brand-new user with none of the above
/// yet. Deliberately still just 2 notifications/day, not more -- a targeted
/// daily ping beats a generic one, but more ever beats a user's tolerance.
String _tr(Progress p, String hi, String en) => p.lang == 'en' ? en : hi;

Future<void> applyReminders(Progress p) async {
  await RailParikshaNotifications.cancelAll();
  if (!p.reminders) return;

  final days = p.daysToExam;
  final examSoon = days != null && days <= 14;

  await RailParikshaNotifications.scheduleDaily(
    id: 1,
    hour: p.reminderHour,
    title: examSoon
        ? _tr(p, 'परीक्षा में सिर्फ $days दिन बाकी! ⏰', 'Only $days days left for your exam! ⏰')
        : _tr(p, 'आपका आज का Daily 10 तैयार है 🔥', "Your Daily 10 is ready 🔥"),
    body: examSoon
        ? _tr(p, 'आज का रिवीज़न अभी शुरू करें, एक भी दिन बर्बाद न करें।', 'Start today\'s revision now -- every day counts.')
        : _tr(p, 'सिर्फ 10 प्रश्न, 5 मिनट। चलिए अभ्यास शुरू करते हैं!', 'Just 10 questions, 5 minutes. Let\'s get started!'),
  );

  final eveningHour = (p.reminderHour + 12) % 24;
  final evening = _eveningMessage(p, examSoon, days);
  await RailParikshaNotifications.scheduleDaily(
    id: 2,
    hour: eveningHour == 0 ? 20 : eveningHour,
    title: evening.$1,
    body: evening.$2,
  );
}

(String, String) _eveningMessage(Progress p, bool examSoon, int? days) {
  if (examSoon) {
    return (
      _tr(p, 'परीक्षा में $days दिन! आज का रिवीज़न पूरा किया? 📚', '$days days to go! Done today\'s revision? 📚'),
      _tr(p, 'आखिरी दिनों में हर घंटा मायने रखता है।', 'Every hour counts in these final days.'),
    );
  }
  if (p.liveStreak > 0) {
    return (
      _tr(p, 'अपनी ${p.liveStreak} दिन की स्ट्रीक आज पूरी करें! 🔥', 'Keep your ${p.liveStreak}-day streak alive today! 🔥'),
      _tr(p, 'रोज़ थोड़ा, पर बिना नागा — यही सफलता का राज़ है।',
          'A little every day, without skipping — that\'s the real secret to success.'),
    );
  }
  if (p.mistakes.length >= 5) {
    return (
      _tr(p, '${p.mistakes.length} गलतियां दोबारा हल करने के लिए तैयार हैं', '${p.mistakes.length} mistakes are ready for a rematch'),
      _tr(p, 'इन्हें अभी ठीक करें, एग्ज़ाम में दोबारा ना हों।', 'Fix them now so they don\'t repeat on exam day.'),
    );
  }
  return (
    _tr(p, 'आज थोड़ा अभ्यास कर लें? 💪', 'A little practice today? 💪'),
    _tr(p, 'रोज़ थोड़ा, पर बिना नागा — यही सफलता का राज़ है।',
        'A little every day, without skipping — that\'s the real secret to success.'),
  );
}
