import 'notifications.dart';
import '../data/progress.dart';

/// Reschedules both reminders from the user's saved settings. Safe to call
/// often (on toggle, on time change, on launch) — cancels and re-adds.
///
/// Message content is re-derived from current state every call, so each
/// day's ping surfaces whichever signal is actually most likely to bring
/// the user back today, in priority order: an imminent exam (escalating in
/// three tiers as it gets closer -- a hard deadline always wins), then a
/// streak about to break (loss aversion is the strongest lever once a
/// streak exists), then a backlog of unreviewed mistakes, and only then a
/// generic nudge for a brand-new user with none of the above yet.
///
/// Within each tier there are several high-energy variants (train-rank
/// imagery, competitive framing, urgency -- not polite generic reminders),
/// picked deterministically off today's day-index so the copy rotates day
/// to day instead of going stale, while staying stable if this function
/// gets called more than once on the same day (e.g. toggling a setting).
///
/// Morning and evening (ids 1-2) fire every day. A third, midday ping (id 3)
/// is conditional, not blanket -- it only fires when there's a genuine
/// high-intent reason to (exam within a week, a streak not yet saved today,
/// or a real mistake backlog), so the extra volume is a real signal, not
/// noise padding toward 3/day regardless of relevance.
///
/// A fourth slot, id 4, is the late-night "streak SOS" -- distinct in tone
/// (its own higher-priority channel, see notifications.dart) and in timing
/// (a fixed late hour, independent of the user's morning/evening times) from
/// the regular evening nudge. It only exists when the streak is actually
/// still unsaved and worth protecting (>= [_streakSosThreshold] days) this
/// evening.
///
/// Local-notification caveat, and how it's handled here: flutter_local_notifications
/// schedules a fixed title/body ahead of time -- it cannot re-check "has the
/// user practiced yet?" at the moment it fires. So eligibility is computed
/// now, at schedule time, not at 9pm. To keep that snapshot from going stale
/// over the following hours, [applyReminders] must be re-run (which cancels
/// and recomputes all four) the moment anything could have flipped the
/// condition: on every app launch, on app resume (see HomeShell), on any
/// reminder-settings change, and -- the case that matters most here --
/// immediately when the user's first qualifying activity of the day lands
/// (see `Progress.onActiveToday`, wired in main.dart). That closes the gap
/// for the common case (open the app, practice, the SOS for tonight is
/// cancelled right then) but not a case no local-only scheme can close: the
/// app never being opened again before 9pm after the streak was saved by some
/// other route, or the clock simply running out with the app in the
/// background the whole time and no resume event firing. There is no way to
/// evaluate "did they practice today" at the exact fire instant without a
/// server push or a background callback, neither of which this app has (by
/// design -- no new dependency). This is the accepted tradeoff.
const _streakSosThreshold = 3;
const _streakSosHour = 21; // 9pm local — inside the "getting late" window, well before midnight.

String _tr(Progress p, String hi, String en) => p.lang == 'en' ? en : hi;

(String, String) _pick(Progress p, List<(String, String, String, String)> variants) {
  final v = variants[today() % variants.length];
  return (_tr(p, v.$1, v.$2), _tr(p, v.$3, v.$4));
}

Future<void> applyReminders(Progress p) async {
  await RailParikshaNotifications.cancelAll();
  if (!p.reminders) return;

  final days = p.daysToExam;
  final morning = _morningMessage(p, days);
  await RailParikshaNotifications.scheduleDaily(
    id: 1,
    hour: p.reminderHour,
    title: morning.$1,
    body: morning.$2,
  );

  final eveningHour = (p.reminderHour + 12) % 24;
  final evening = _eveningMessage(p, days);
  await RailParikshaNotifications.scheduleDaily(
    id: 2,
    hour: eveningHour == 0 ? 20 : eveningHour,
    title: evening.$1,
    body: evening.$2,
  );

  final midday = _middayMessage(p, days);
  if (midday != null) {
    final middayHour = (p.reminderHour + 6) % 24;
    await RailParikshaNotifications.scheduleDaily(
      id: 3,
      hour: middayHour,
      title: midday.$1,
      body: midday.$2,
      recurring: false,
    );
  }

  if (p.streakRiskAlerts) {
    final sos = _streakSosMessage(p);
    if (sos != null) {
      await RailParikshaNotifications.scheduleDaily(
        id: 4,
        hour: _streakSosHour,
        title: sos.$1,
        body: sos.$2,
        urgent: true,
        recurring: false,
      );
    }
  }
}

/// Only returns a message (and so only fires id 4) when there's a real
/// streak worth saving and it hasn't been saved yet today -- see the caveat
/// on staleness above [_streakSosThreshold].
(String, String)? _streakSosMessage(Progress p) {
  final streak = p.liveStreak;
  if (streak < _streakSosThreshold || p.activeToday) return null;
  return _pick(p, [
    (
      'आपकी $streak दिन की स्ट्रीक खतरे में है! 🚨',
      'Your $streak-day streak is at risk! 🚨',
      'आज अभी अभ्यास करें, आधी रात से पहले बचा लें!',
      'Practice now to keep it alive before midnight!',
    ),
    (
      '$streak दिन, और रात होने वाली है ⏳🔥',
      '$streak days, and night is closing in ⏳🔥',
      'अभी एक क्विज़ खेलो, स्ट्रीक मत टूटने दो!',
      "Play one quiz right now — don't let it break!",
    ),
  ]);
}

/// Only returns a message (and so only fires id 3) when there's a genuine
/// high-intent reason -- not sent unconditionally like the morning/evening pair.
(String, String)? _middayMessage(Progress p, int? days) {
  if (days != null && days <= 7) {
    return (
      _tr(p, '$days दिन! दोपहर का रिवीज़न छोड़ा मत! ⏰', "$days days left! Don't skip your midday revision! ⏰"),
      _tr(p, 'आखिरी हफ्तों में हर सेशन मायने रखता है।', 'Every session counts in these final weeks.'),
    );
  }
  final streak = p.liveStreak;
  if (streak >= 3 && !p.activeToday) {
    return _pick(p, [
      (
        '$streak दिन की स्ट्रीक अभी बचाओ! 🔥',
        'Save your $streak-day streak right now! 🔥',
        'आज अभी तक कुछ नहीं किया — एक क्विज़ खेलो!',
        "You haven't practiced today yet — play one quiz!",
      ),
      (
        'दोपहर हो गई, स्ट्रीक का क्या? ⏳',
        'It\'s midday — what about your streak? ⏳',
        '$streak दिन बचाने के लिए बस एक क्विज़ चाहिए।',
        'Just one quiz saves your $streak-day streak.',
      ),
    ]);
  }
  final mistakes = p.mistakes.length;
  if (mistakes >= 10) {
    return (
      _tr(p, '$mistakes गलतियां जमा हो गई हैं 😬', '$mistakes mistakes have piled up 😬'),
      _tr(p, 'Mistake Book खोलो और आज ही साफ़ करो!', 'Open your Mistake Book and clear it today!'),
    );
  }
  return null;
}

(String, String) _morningMessage(Progress p, int? days) {
  if (days != null && days <= 3) {
    return (
      _tr(p, '🚨 सिर्फ $days दिन बाकी! 🚨', '🚨 Only $days days left! 🚨'),
      _tr(p, 'अभी रिवीज़न शुरू करो, एक मिनट भी बर्बाद मत करो!', "Start revising right now — don't waste a single minute!"),
    );
  }
  if (days != null && days <= 7) {
    return (
      _tr(p, 'परीक्षा में सिर्फ $days दिन! ⏰', 'Only $days days to your exam! ⏰'),
      _tr(p, 'आज का रिवीज़न अभी शुरू करो, हर घंटा कीमती है।', 'Start revising now — every hour counts.'),
    );
  }
  if (days != null && days <= 14) {
    return (
      _tr(p, 'परीक्षा में सिर्फ $days दिन बाकी! ⏰', 'Only $days days left for your exam! ⏰'),
      _tr(p, 'आज का रिवीज़न अभी शुरू करें, एक भी दिन बर्बाद न करें।', "Start today's revision now — every day counts."),
    );
  }
  return _pick(p, const [
    (
      'उठो चैंपियन! 🔥',
      'Rise and grind, champion! 🔥',
      'तुम्हारा आज का Daily 10 तैयार है — सिर्फ 5 मिनट में बाज़ी मार लो!',
      'Your Daily 10 is ready — smash it in just 5 minutes!',
    ),
    (
      'भारतीय रेलवे बुला रही है 🚆',
      'Indian Railways is calling 🚆',
      'तैयार हो आज की सीट पक्की करने के लिए? चलो शुरू करें!',
      "Ready to lock in today's seat? Let's start!",
    ),
    (
      'हर सुबह एक जीत 🏆',
      'Every morning, a new win 🏆',
      'सिर्फ 10 सवाल, 5 मिनट — आज की जीत शुरू करो।',
      "Just 10 questions, 5 minutes — start today's win.",
    ),
    (
      'तुम्हारी सीट तुम्हारा इंतज़ार कर रही है 🚂',
      'Your seat on that train is waiting 🚂',
      'आज का अभ्यास छोड़ा तो कोई और आगे निकल जाएगा!',
      'Skip today and someone else moves ahead!',
    ),
    (
      'जोश में हो? चलो शुरू करें! ⚡',
      "Feeling it? Let's go! ⚡",
      'आज का Daily 10 पूरा करके अपना दिन शुरू करो।',
      "Kick off your day by finishing today's Daily 10.",
    ),
  ]);
}

(String, String) _eveningMessage(Progress p, int? days) {
  if (days != null && days <= 3) {
    return (
      _tr(p, '$days दिन! आखिरी मौका है 🔥', '$days days! This is your final push 🔥'),
      _tr(p, 'जो आज रिवीज़न करेगा, वही कल जीतेगा।', 'Whoever revises today wins tomorrow.'),
    );
  }
  if (days != null && days <= 7) {
    return (
      _tr(p, '$days दिन बाकी! रिवीज़न पूरा किया? 📚', '$days days left! Done revising? 📚'),
      _tr(p, 'आखिरी हफ्तों में हर घंटा मायने रखता है।', 'Every hour matters in these final weeks.'),
    );
  }
  if (days != null && days <= 14) {
    return (
      _tr(p, '$days दिन! आज का रिवीज़न पूरा किया? 📚', "$days days to go! Done today's revision? 📚"),
      _tr(p, 'आखिरी दिनों में हर घंटा मायने रखता है।', 'Every hour counts in these final days.'),
    );
  }
  final streak = p.liveStreak;
  if (streak > 0) {
    return _pick(p, [
      (
        '$streak दिन की स्ट्रीक टूटने वाली है! 🔥🚨',
        'Your $streak-day streak is about to die! 🔥🚨',
        'अभी एक क्विज़ खेलो और इसे ज़िंदा रखो!',
        'Play one quiz right now and keep it alive!',
      ),
      (
        'राजधानी बनने से एक क्विज़ दूर हो 🚄',
        'One quiz away from Rajdhani rank 🚄',
        '$streak दिन की मेहनत बर्बाद मत करो — आज भी खेलो!',
        "Don't waste $streak days of hard work — play today too!",
      ),
      (
        'तुम्हारी स्ट्रीक को तुम्हारी ज़रूरत है! 💪',
        'Your streak needs you! 💪',
        '$streak दिन की स्ट्रीक — आज भी बरकरार रखो।',
        'Keep that $streak-day streak alive today too.',
      ),
      (
        'वंदे भारत बनने से एक क्विज़ दूर हो 🚅',
        'One quiz away from Vande Bharat rank 🚅',
        '$streak दिन की स्पीड मत गिरने दो — आज भी खेलो!',
        "Don't let your $streak-day speed drop — play today too!",
      ),
    ]);
  }
  final mistakes = p.mistakes.length;
  if (mistakes >= 5) {
    return _pick(p, [
      (
        '$mistakes गलतियां बदला लेने का इंतज़ार कर रही हैं 😤',
        '$mistakes mistakes are waiting for their revenge match 😤',
        'इन्हें आज हरा दो, एग्ज़ाम में दोबारा मौका नहीं मिलेगा!',
        "Beat them today — exam day won't give you a second chance!",
      ),
      (
        '$mistakes गलतियां, एक मौका ⚔️',
        '$mistakes mistakes, one shot ⚔️',
        'Mistake Book खोलो और स्कोर बराबर करो!',
        'Open your Mistake Book and even the score!',
      ),
    ]);
  }
  return _pick(p, const [
    (
      'दिन खत्म होने से पहले! ⏳',
      'Before the day ends! ⏳',
      'सिर्फ 5 मिनट बचे हैं आज की जीत के लिए — अभी शुरू करो!',
      "Just 5 minutes stand between you and today's win — go now!",
    ),
    (
      'आज की बाज़ी अभी बाकी है 🎯',
      "Today's win is still up for grabs 🎯",
      'एक छोटा सा अभ्यास, एक बड़ा कदम सफलता की ओर।',
      'One small practice session, one big step toward success.',
    ),
    (
      'कामयाबी इंतज़ार नहीं करती ⚡',
      "Success doesn't wait ⚡",
      'आज थोड़ा अभ्यास कर लो, कल खुद को शुक्रिया कहोगे।',
      "Practice a little today — you'll thank yourself tomorrow.",
    ),
  ]);
}
