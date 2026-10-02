import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  (0.0, 'रूकी', 'Rookie'),
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

/// Events the UI celebrates after an answer or review.
class Reward {
  final int xp;
  final bool goalCompleted;
  final bool levelUp;
  final int? streakMilestone;
  const Reward(this.xp, {this.goalCompleted = false, this.levelUp = false, this.streakMilestone});
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
  String theme = 'system';
  bool reminders = true;
  int reminderHour = 7;
  bool streakRiskAlerts = true;

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
  bool comeback = false;
  int bestSpeed = 0;
  double beastBestScore = 0;
  int beastBestStreak = 0;
  final Map<int, int> dayCounts = {};

  // Learning state
  final Map<String, List<int>> qStats = {}; // id -> [attempts, correct, lastCorrect]
  final Set<String> mistakes = {};
  final Set<String> bookmarks = {};
  final Set<String> reported = {};
  final Map<String, CardState> cards = {};
  final List<MockResult> mocks = [];

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
    theme = j['theme'] ?? 'system';
    reminders = j['reminders'] ?? true;
    reminderHour = j['reminderHour'] ?? 7;
    streakRiskAlerts = j['streakRiskAlerts'] ?? true;
    xp = j['xp'] ?? 0;
    streak = j['streak'] ?? 0;
    bestStreak = j['bestStreak'] ?? 0;
    lastActiveDay = j['lastActiveDay'] ?? 0;
    freezeTokens = j['freezeTokens'] ?? 0;
    lastShareDay = j['lastShareDay'] ?? 0;
    bestSpeed = j['bestSpeed'] ?? 0;
    beastBestScore = (j['beastBestScore'] as num?)?.toDouble() ?? 0;
    beastBestStreak = j['beastBestStreak'] ?? 0;
    (j['dayCounts'] as Map? ?? {}).forEach((k, v) => dayCounts[int.parse(k)] = v);
    (j['qStats'] as Map? ?? {}).forEach((k, v) => qStats[k] = List<int>.from(v));
    mistakes.addAll(List<String>.from(j['mistakes'] ?? []));
    bookmarks.addAll(List<String>.from(j['bookmarks'] ?? []));
    reported.addAll(List<String>.from(j['reported'] ?? []));
    (j['cards'] as Map? ?? {}).forEach((k, v) => cards[k] = CardState.fromJson(v));
    mocks.addAll((j['mocks'] as List? ?? []).map((m) => MockResult.fromJson(m)));
  }

  Map<String, dynamic> _toJson() => {
        'onboarded': onboarded,
        'lang': lang,
        'name': name,
        'examId': examId,
        'dailyGoal': dailyGoal,
        'placementLevel': placementLevel,
        'examDate': examDate?.toIso8601String(),
        'theme': theme,
        'reminders': reminders,
        'reminderHour': reminderHour,
        'streakRiskAlerts': streakRiskAlerts,
        'xp': xp,
        'streak': streak,
        'bestStreak': bestStreak,
        'lastActiveDay': lastActiveDay,
        'freezeTokens': freezeTokens,
        'lastShareDay': lastShareDay,
        'bestSpeed': bestSpeed,
        'beastBestScore': beastBestScore,
        'beastBestStreak': beastBestStreak,
        'dayCounts': dayCounts.map((k, v) => MapEntry('$k', v)),
        'qStats': qStats,
        'mistakes': mistakes.toList(),
        'bookmarks': bookmarks.toList(),
        'reported': reported.toList(),
        'cards': cards.map((k, v) => MapEntry(k, v.toJson())),
        'mocks': mocks.map((m) => m.toJson()).toList(),
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
  void _touchDay() {
    final t = today();
    if (lastActiveDay == t) return;
    final gap = t - lastActiveDay;
    if (gap == 1) {
      streak += 1;
      comeback = false;
    } else if (gap == 2 && freezeTokens > 0) {
      freezeTokens -= 1;
      streak += 1;
      comeback = false;
    } else {
      comeback = lastActiveDay != 0;
      streak = 1;
    }
    lastActiveDay = t;
    if (streak > bestStreak) bestStreak = streak;
  }

  static const milestones = [3, 7, 21, 50, 100, 200, 365];

  Reward _gain(int amount, {bool countsTowardGoal = true}) {
    final wasActive = activeToday;
    final beforeLevel = level.index;
    final beforeGoal = todayCount >= dailyGoal;
    _touchDay();
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
        goalCompleted: goalNow, levelUp: level.index > beforeLevel, streakMilestone: milestone);
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
    return _gain(correct ? 10 : 2);
  }

  Reward reviewCard(String id, bool good) {
    final t = today();
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

  Future<void> reset() async {
    final keepLang = lang;
    xp = streak = bestStreak = lastActiveDay = freezeTokens = bestSpeed = beastBestStreak = lastShareDay = 0;
    beastBestScore = 0;
    for (final c in [dayCounts, qStats, cards]) {
      c.clear();
    }
    mistakes.clear();
    bookmarks.clear();
    reported.clear();
    mocks.clear();
    onboarded = false;
    examId = null;
    placementLevel = null;
    examDate = null;
    lang = keepLang;
    save(now: true);
  }
}
