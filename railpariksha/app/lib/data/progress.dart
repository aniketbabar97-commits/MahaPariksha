import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

int dayIndex(DateTime t) => DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;
int today() => dayIndex(DateTime.now());

class Level {
  final int index;
  final String hi;
  final String en;
  final int minXp;
  final int? nextXp;
  const Level(this.index, this.hi, this.en, this.minXp, this.nextXp);
  String of(String lang) => lang == 'en' ? en : hi;
}

/// Levels follow a train's own upgrade path — General to Vande Bharat — to
/// match the app's theme. Vande Bharat tops the list, not Rajdhani: it's
/// India's fastest and most modern train in service today, so it reads as
/// the more aspirational finish line for a RRB/RPF aspirant right now.
const _levels = [
  (0, 'जनरल', 'General'),
  (300, 'स्लीपर', 'Sleeper'),
  (1500, 'थर्ड एसी', 'AC 3-Tier'),
  (5000, 'सेकंड एसी', 'AC 2-Tier'),
  (12000, 'राजधानी', 'Rajdhani'),
  (25000, 'वंदे भारत', 'Vande Bharat'),
];

class BeastTier {
  final int index;
  final String hi;
  final String en;
  final double minScore;
  final double? nextScore;
  const BeastTier(this.index, this.hi, this.en, this.minScore, this.nextScore);
  String of(String lang) => lang == 'en' ? en : hi;
}

/// Beast Mode tiers, unlocked by the best sprint score achieved so far (see
/// [Progress.beastBestScore]). Mirrors [_levels]' shape/lookup pattern.
const _beastTiers = [
  (0.0, 'नौसिखिया', 'Rookie'),
  (15.0, 'योद्धा', 'Warrior'),
  (30.0, 'बीस्ट', 'Beast'),
  (50.0, 'आयरन बीस्ट', 'Iron Beast'),
  (75.0, 'एग्ज़ाम बीस्ट', 'Exam Beast'),
];

class CardState {
  double ease;
  int interval;
  int due;
  int reps;
  final int firstSeen;
  CardState({this.ease = 2.5, this.interval = 0, required this.due, this.reps = 0, int? firstSeen})
      : firstSeen = firstSeen ?? due;
  Map<String, dynamic> toJson() => {'e': ease, 'i': interval, 'd': due, 'r': reps, 'f': firstSeen};
  factory CardState.fromJson(Map<String, dynamic> j) => CardState(
      ease: (j['e'] as num).toDouble(), interval: j['i'], due: j['d'], reps: j['r'], firstSeen: j['f']);
}

class MockResult {
  final int day;
  final String examId;
  final double score;
  final int total;
  const MockResult(this.day, this.examId, this.score, this.total);
  Map<String, dynamic> toJson() => {'day': day, 'exam': examId, 'score': score, 'total': total};
  factory MockResult.fromJson(Map<String, dynamic> j) =>
      MockResult(j['day'], j['exam'], (j['score'] as num).toDouble(), j['total']);
}

/// A mock test left before submitting. A full paper runs 90+ minutes and
/// Android may kill a backgrounded app, so the attempt is saved to resume.
class PausedMock {
  final String examId;
  final List<String> questionIds;
  final String titleHi;
  final String titleEn;
  final double negative;
  final int? timeLimitSec;
  final int remainingSec;
  final List<int?> answers;
  final List<int> marked;
  final List<int> visited;
  final int index;
  final List<int> timeMs;
  const PausedMock({
    required this.examId,
    required this.questionIds,
    required this.titleHi,
    required this.titleEn,
    required this.negative,
    required this.timeLimitSec,
    required this.remainingSec,
    required this.answers,
    required this.marked,
    required this.visited,
    required this.index,
    required this.timeMs,
  });

  int get answeredCount => answers.where((a) => a != null).length;

  Map<String, dynamic> toJson() => {
        'exam': examId,
        'ids': questionIds,
        'titleHi': titleHi,
        'titleEn': titleEn,
        'negative': negative,
        'limit': timeLimitSec,
        'remaining': remainingSec,
        'answers': answers,
        'marked': marked,
        'visited': visited,
        'index': index,
        'timeMs': timeMs,
      };

  factory PausedMock.fromJson(Map<String, dynamic> j) => PausedMock(
        examId: j['exam'] ?? '',
        questionIds: List<String>.from(j['ids']),
        titleHi: j['titleHi'] ?? '',
        titleEn: j['titleEn'] ?? '',
        negative: (j['negative'] as num?)?.toDouble() ?? 0,
        timeLimitSec: j['limit'],
        remainingSec: j['remaining'] ?? 0,
        answers: List<int?>.from(j['answers']),
        marked: List<int>.from(j['marked'] ?? const []),
        visited: List<int>.from(j['visited'] ?? const []),
        index: j['index'] ?? 0,
        timeMs: List<int>.from(j['timeMs'] ?? const []),
      );
}

/// Events the UI celebrates after an answer or review.
class Reward {
  final int xp;
  final bool goalCompleted;
  final bool levelUp;
  final int? streakMilestone;
  final bool freezeSaved;
  const Reward(this.xp,
      {this.goalCompleted = false, this.levelUp = false, this.streakMilestone, this.freezeSaved = false});
}

class Progress extends ChangeNotifier {
  // Settings
  bool onboarded = false;
  String lang = 'hi';
  String name = '';
  String? examId;
  int dailyGoal = 20;
  /// Result of the onboarding diagnostic quiz: 'beginner' / 'intermediate' / 'advanced',
  /// or null if the user skipped it. Informational only -- never gates anything.
  String? placementLevel;
  DateTime? examDate;

  /// Stable anonymous identity for the leaderboard (see logic/leaderboard_service.dart) --
  /// generated once on first use and persisted, never tied to any real account. Null until
  /// the leaderboard is opened for the first time.
  String? deviceId;

  /// Display name shown on the leaderboard (chosen by the user, not a real identity).
  /// Null until they've set one.
  String? leaderboardName;
  String theme = 'dark'; // dark is the house look; Light / System stay available in Me
  bool reminders = true;
  int reminderHour = 7;
  bool streakRiskAlerts = true;

  /// One-time purchase entitlement (`remove_ads_offline`, see
  /// lib/core/purchases.dart): removes all ads and is the flag the market
  /// survey's price-sensitive users are paying for instead of a subscription.
  /// "Offline mode" is this app's existing offline-first behaviour (see
  /// ads.dart) -- there's nothing else to unlock there, it's marketing
  /// framing for a true today. Set by PurchaseManager on a verified purchase
  /// or successful restore; never set directly from UI.
  bool _removedAds = false;

  /// True while no ads should show: the one-time purchase, or an ad-free hour earned by
  /// watching a rewarded ad (see [grantAdFreeHour]). Every ad surface checks this.
  bool get removedAds => _removedAds || adFreeActive;
  set removedAds(bool v) => _removedAds = v;

  /// The purchase alone (what the Premium card and restore flow care about).
  bool get premium => _removedAds;

  /// End of an ad-free window earned by a rewarded ad; null when none was ever earned.
  DateTime? adFreeUntil;
  bool get adFreeActive => adFreeUntil != null && DateTime.now().isBefore(adFreeUntil!);
  Duration get adFreeLeft => adFreeActive ? adFreeUntil!.difference(DateTime.now()) : Duration.zero;

  /// Rewarded-ad reward: one hour without ads. Earns rewarded eCPM and gives heavy users a
  /// breather; windows don't stack beyond an hour from now.
  void grantAdFreeHour() {
    adFreeUntil = DateTime.now().add(const Duration(hours: 1));
    save();
    notifyListeners();
  }

  /// Day the Current Affairs digest was last opened, for the Today mission.
  int? caReadDay;
  bool get caReadToday => caReadDay == today();
  void markCaRead() {
    if (caReadToday) return;
    caReadDay = today();
    save();
    notifyListeners();
  }

  /// Flashcards reviewed today (any answer), for the Today mission.
  int? _cardsDay;
  int _cardsToday = 0;
  int get cardsReviewedToday => _cardsDay == today() ? _cardsToday : 0;

  /// Quizzes and papers finished to the results screen; paces interstitials (see AdPacing).
  int quizzesDone = 0;

  /// Fired once, right as [_gain] marks the user active for today (i.e. the
  /// first qualifying activity of the day just landed). Set by main.dart to
  /// reschedule reminders immediately, so a late-night streak-SOS already
  /// queued for tonight gets cancelled the moment it's no longer warranted --
  /// see the staleness caveat in reminders.dart. Not persisted; a plain
  /// in-memory hook, since it only matters while the app is running.
  void Function()? onActiveToday;

  // Gamification
  int xp = 0;
  int streak = 0;
  int bestStreak = 0;
  int lastActiveDay = 0;
  int freezeTokens = 0;
  int lastShareDay = 0;
  int lastReviewAskDay = 0;
  int reviewAsks = 0;
  bool comeback = false;
  int bestSpeed = 0;
  double beastBestScore = 0;
  int beastBestStreak = 0;
  // Sticky unlock flag: once overall accuracy ever clears the Beast Mode gate,
  // it stays unlocked even if accuracy later dips from unrelated practice --
  // otherwise a feature the user already earned (and may have a tier in) can
  // vanish again, which reads as a bug/regression rather than a fair gate.
  bool beastEverUnlocked = false;
  final Map<int, int> dayCounts = {};

  // Learning state
  final Map<String, List<int>> qStats = {}; // id -> [attempts, correct, lastCorrect]
  final Set<String> mistakes = {};
  final Set<String> bookmarks = {};
  final Set<String> reported = {};
  final Map<String, CardState> cards = {};
  final List<MockResult> mocks = [];
  PausedMock? pausedMock;

  File? _file;
  Timer? _saveTimer;

  Future<void> load() async {
    try {
      _file = File('${(await getApplicationSupportDirectory()).path}/progress.json');
      if (!await _file!.exists()) return;
      _fromJson(jsonDecode(await _file!.readAsString()));
    } catch (_) {
      // Unreadable file or no storage: start fresh rather than crash on launch.
    }
  }

  void _fromJson(Map<String, dynamic> j) {
    onboarded = j['onboarded'] ?? false;
    lang = j['lang'] ?? 'hi';
    name = j['name'] ?? '';
    examId = j['examId'];
    dailyGoal = j['dailyGoal'] ?? 20;
    placementLevel = j['placementLevel'];
    examDate = j['examDate'] != null ? DateTime.tryParse(j['examDate']) : null;
    deviceId = j['deviceId'];
    leaderboardName = j['leaderboardName'];
    theme = j['theme'] ?? 'dark';
    reminders = j['reminders'] ?? true;
    reminderHour = j['reminderHour'] ?? 7;
    streakRiskAlerts = j['streakRiskAlerts'] ?? true;
    _removedAds = j['removedAds'] ?? false;
    adFreeUntil = j['adFreeUntil'] == null ? null : DateTime.tryParse(j['adFreeUntil']);
    caReadDay = j['caReadDay'];
    _cardsDay = j['cardsDay'];
    _cardsToday = j['cardsToday'] ?? 0;
    quizzesDone = j['quizzesDone'] ?? 0;
    xp = j['xp'] ?? 0;
    streak = j['streak'] ?? 0;
    bestStreak = j['bestStreak'] ?? 0;
    lastActiveDay = j['lastActiveDay'] ?? 0;
    freezeTokens = j['freezeTokens'] ?? 0;
    lastShareDay = j['lastShareDay'] ?? 0;
    lastReviewAskDay = j['lastReviewAskDay'] ?? 0;
    reviewAsks = j['reviewAsks'] ?? 0;
    bestSpeed = j['bestSpeed'] ?? 0;
    beastBestScore = (j['beastBestScore'] as num?)?.toDouble() ?? 0;
    beastBestStreak = j['beastBestStreak'] ?? 0;
    beastEverUnlocked = j['beastEverUnlocked'] ?? false;
    (j['dayCounts'] as Map? ?? {}).forEach((k, v) => dayCounts[int.parse(k)] = v);
    (j['qStats'] as Map? ?? {}).forEach((k, v) => qStats[k] = List<int>.from(v));
    mistakes.addAll(List<String>.from(j['mistakes'] ?? []));
    bookmarks.addAll(List<String>.from(j['bookmarks'] ?? []));
    reported.addAll(List<String>.from(j['reported'] ?? []));
    (j['cards'] as Map? ?? {}).forEach((k, v) => cards[k] = CardState.fromJson(v));
    mocks.addAll((j['mocks'] as List? ?? []).map((m) => MockResult.fromJson(m)));
    try {
      final pm = j['pausedMock'];
      pausedMock = pm == null ? null : PausedMock.fromJson(pm);
    } catch (_) {
      pausedMock = null; // Malformed snapshot: losing one paused test beats failing to load.
    }
  }

  Map<String, dynamic> _toJson() => {
        'onboarded': onboarded,
        'lang': lang,
        'name': name,
        'examId': examId,
        'dailyGoal': dailyGoal,
        'placementLevel': placementLevel,
        'examDate': examDate?.toIso8601String(),
        'deviceId': deviceId,
        'leaderboardName': leaderboardName,
        'theme': theme,
        'reminders': reminders,
        'reminderHour': reminderHour,
        'streakRiskAlerts': streakRiskAlerts,
        'removedAds': _removedAds,
        if (adFreeUntil != null) 'adFreeUntil': adFreeUntil!.toIso8601String(),
        if (caReadDay != null) 'caReadDay': caReadDay,
        if (_cardsDay != null) 'cardsDay': _cardsDay,
        'cardsToday': _cardsToday,
        'quizzesDone': quizzesDone,
        'xp': xp,
        'streak': streak,
        'bestStreak': bestStreak,
        'lastActiveDay': lastActiveDay,
        'freezeTokens': freezeTokens,
        'lastShareDay': lastShareDay,
        'lastReviewAskDay': lastReviewAskDay,
        'reviewAsks': reviewAsks,
        'bestSpeed': bestSpeed,
        'beastBestScore': beastBestScore,
        'beastBestStreak': beastBestStreak,
        'beastEverUnlocked': beastEverUnlocked,
        'dayCounts': dayCounts.map((k, v) => MapEntry('$k', v)),
        'qStats': qStats,
        'mistakes': mistakes.toList(),
        'bookmarks': bookmarks.toList(),
        'reported': reported.toList(),
        'cards': cards.map((k, v) => MapEntry(k, v.toJson())),
        'mocks': mocks.map((m) => m.toJson()).toList(),
        'pausedMock': pausedMock?.toJson(),
      };

  void save({bool now = false}) {
    notifyListeners();
    _saveTimer?.cancel();
    if (now) {
      _write();
    } else {
      _saveTimer = Timer(const Duration(milliseconds: 600), _write);
    }
  }

  Future<void> _write() async {
    final f = _file;
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(_toJson()));
      await tmp.rename(f.path);
    } catch (_) {
      // Disk full or storage revoked: keep the in-memory state; the next save retries.
    }
  }

  // ---------- Derived ----------
  int get todayCount => dayCounts[today()] ?? 0;
  double get goalProgress => (todayCount / dailyGoal).clamp(0.0, 1.0);
  bool get activeToday => lastActiveDay == today();

  /// Streak as shown: a streak is alive if the user was active today or yesterday.
  int get liveStreak => (today() - lastActiveDay) <= 1 ? streak : 0;

  Level get level {
    for (var i = _levels.length - 1; i >= 0; i--) {
      if (xp >= _levels[i].$1) {
        final next = i + 1 < _levels.length ? _levels[i + 1].$1 : null;
        return Level(i, _levels[i].$2, _levels[i].$3, _levels[i].$1, next);
      }
    }
    return Level(0, _levels[0].$2, _levels[0].$3, 0, _levels[1].$1);
  }

  /// Derived from [beastBestScore], the same way [level] is derived from [xp] —
  /// no separate stored tier field, so it can never drift out of sync with the score.
  BeastTier get beastTier {
    for (var i = _beastTiers.length - 1; i >= 0; i--) {
      if (beastBestScore >= _beastTiers[i].$1) {
        final next = i + 1 < _beastTiers.length ? _beastTiers[i + 1].$1 : null;
        return BeastTier(i, _beastTiers[i].$2, _beastTiers[i].$3, _beastTiers[i].$1, next);
      }
    }
    return BeastTier(0, _beastTiers[0].$2, _beastTiers[0].$3, 0, _beastTiers[1].$1);
  }

  int? get daysToExam {
    final d = examDate;
    if (d == null) return null;
    final n = dayIndex(d) - today();
    return n < 0 ? null : n;
  }

  int get totalAnswered => qStats.values.fold(0, (a, s) => a + s[0]);
  int get totalCorrect => qStats.values.fold(0, (a, s) => a + s[1]);
  double get accuracy => totalAnswered == 0 ? 0 : totalCorrect / totalAnswered;

  /// Whether now is a good moment to ask for a Play Store rating: only an
  /// engaged learner (real history, a streak going) right after a good
  /// session, at most 3 times ever and never within 60 days of the last ask.
  /// Play's own quota still decides whether the dialog actually shows.
  bool shouldAskForReview({required double sessionScore}) =>
      sessionScore >= 0.7 &&
      totalAnswered >= 100 &&
      liveStreak >= 3 &&
      reviewAsks < 3 &&
      (lastReviewAskDay == 0 || today() - lastReviewAskDay >= 60);

  void markReviewAsked() {
    lastReviewAskDay = today();
    reviewAsks++;
    save();
  }

  static const newCardsPerDay = 20;
  int get newCardsSeenToday => cards.values.where((c) => c.firstSeen == today()).length;

  int dueCardCount(Iterable<String> ids) {
    final t = today();
    var n = 0;
    for (final id in ids) {
      final c = cards[id];
      if (c == null || c.due <= t) n++;
    }
    return n;
  }

  // ---------- Mutations ----------
  /// Returns true if a freeze token was just spent to bridge a missed day,
  /// so callers can surface that save instead of letting the streak silently
  /// carry on as if nothing happened.
  bool _touchDay() {
    final t = today();
    if (lastActiveDay == t) return false;
    final gap = t - lastActiveDay;
    var freezeUsed = false;
    if (gap == 1) {
      streak += 1;
      comeback = false;
    } else if (gap == 2 && freezeTokens > 0) {
      freezeTokens -= 1;
      streak += 1;
      comeback = false;
      freezeUsed = true;
    } else {
      comeback = lastActiveDay != 0;
      streak = 1;
    }
    lastActiveDay = t;
    if (streak > bestStreak) bestStreak = streak;
    return freezeUsed;
  }

  static const milestones = [3, 7, 21, 50, 100, 200, 365];

  Reward _gain(int amount, {bool countsTowardGoal = true}) {
    final wasActive = activeToday;
    final beforeLevel = level.index;
    final beforeGoal = todayCount >= dailyGoal;
    final freezeSaved = _touchDay();
    int? milestone;
    if (!wasActive && milestones.contains(streak)) {
      milestone = streak;
      if (streak % 7 == 0 && freezeTokens < 2) freezeTokens++;
    }
    if (countsTowardGoal) dayCounts[today()] = todayCount + 1;
    var gained = amount;
    final goalNow = !beforeGoal && todayCount >= dailyGoal;
    if (goalNow) gained += 50;
    xp += gained;
    save();
    // Today's first qualifying activity just landed -- let main.dart know so
    // it can re-pick tonight's notifications now rather than leaving a
    // just-invalidated streak-SOS queued for later (see reminders.dart).
    if (!wasActive && activeToday) onActiveToday?.call();
    return Reward(gained,
        goalCompleted: goalNow,
        levelUp: level.index > beforeLevel,
        streakMilestone: milestone,
        freezeSaved: freezeSaved);
  }

  Reward recordAnswer(String qid, bool correct) {
    final s = qStats.putIfAbsent(qid, () => [0, 0, 0]);
    s[0]++;
    if (correct) s[1]++;
    s[2] = correct ? 1 : 0;
    if (correct) {
      mistakes.remove(qid);
    } else {
      mistakes.add(qid);
    }
    if (!beastEverUnlocked && totalAnswered >= 20 && accuracy >= 0.5) beastEverUnlocked = true;
    return _gain(correct ? 10 : 2);
  }

  Reward reviewCard(String id, bool good) {
    final t = today();
    if (_cardsDay != t) {
      _cardsDay = t;
      _cardsToday = 0;
    }
    _cardsToday++;
    final c = cards.putIfAbsent(id, () => CardState(due: t));
    if (good) {
      c.reps += 1;
      c.interval = c.reps == 1 ? 1 : (c.reps == 2 ? 3 : (c.interval * c.ease).round());
      c.ease = (c.ease + 0.05).clamp(1.3, 3.0);
    } else {
      c.reps = 0;
      c.interval = 0;
      c.ease = (c.ease - 0.2).clamp(1.3, 3.0);
    }
    c.due = t + c.interval;
    return _gain(3, countsTowardGoal: false);
  }

  /// Extra XP from an opt-in reward (e.g. "double your XP" after watching an ad).
  void bonusXp(int amount) {
    xp += amount;
    save();
  }

  /// A quiz or paper reached its results screen. Returns the new total.
  int recordQuizDone() {
    quizzesDone++;
    save();
    return quizzesDone;
  }

  void recordMock(MockResult r) {
    mocks.add(r);
    if (mocks.length > 100) mocks.removeAt(0);
    xp += 30;
    save();
  }

  /// Once-per-day XP nudge for actually using the "Invite friends" share sheet --
  /// a small, honest incentive for the one in-app action that can bring in new
  /// users, since there's no install-attribution backend to reward a real referral.
  bool claimShareReward() {
    final t = today();
    if (lastShareDay == t) return false;
    lastShareDay = t;
    xp += 25;
    save();
    return true;
  }

  void recordSpeed(int score) {
    if (score > bestSpeed) bestSpeed = score;
    save();
  }

  /// [score] is the sprint's final Beast Mode score (streak-multiplier gains minus real
  /// negative marking); [streakRun] is the longest correct-in-a-row streak reached in that run.
  void recordBeast(double score, int streakRun) {
    if (score > beastBestScore) beastBestScore = score;
    if (streakRun > beastBestStreak) beastBestStreak = streakRun;
    save();
  }

  /// Lazily generates and persists this device's anonymous leaderboard identity on
  /// first use, so most users who never open the leaderboard never get one at all.
  String ensureDeviceId() {
    var id = deviceId;
    if (id == null) {
      final rnd = Random();
      id = List.generate(16, (_) => rnd.nextInt(36).toRadixString(36)).join();
      deviceId = id;
      save();
    }
    return id;
  }

  void setLeaderboardName(String name) {
    leaderboardName = name.trim().isEmpty ? null : name.trim();
    save();
  }

  void toggleBookmark(String id) {
    bookmarks.contains(id) ? bookmarks.remove(id) : bookmarks.add(id);
    save();
  }

  void report(String id) {
    reported.add(id);
    save();
  }

  void clearComeback() {
    comeback = false;
    save();
  }

  void update(void Function(Progress p) fn) {
    fn(this);
    save();
  }

  /// Saves (or with null, clears) the in-progress mock. [now] writes
  /// immediately, for when the process may be killed right after.
  void setPausedMock(PausedMock? m, {bool now = false}) {
    pausedMock = m;
    save(now: now);
  }

  Future<void> reset() async {
    final keepLang = lang;
    xp = streak = bestStreak = lastActiveDay = freezeTokens = bestSpeed = beastBestStreak = lastShareDay = 0;
    beastBestScore = 0;
    beastEverUnlocked = false;
    for (final c in [dayCounts, qStats, cards]) {
      c.clear();
    }
    mistakes.clear();
    bookmarks.clear();
    reported.clear();
    mocks.clear();
    pausedMock = null;
    onboarded = false;
    examId = null;
    placementLevel = null;
    examDate = null;
    lang = keepLang;
    save(now: true);
  }
}
