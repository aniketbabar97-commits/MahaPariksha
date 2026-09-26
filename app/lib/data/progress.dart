import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

int dayIndex(DateTime t) => DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;
int today() => dayIndex(DateTime.now());

class Level {
  final int index;
  final String mr;
  final String en;
  final int minXp;
  final int? nextXp;
  const Level(this.index, this.mr, this.en, this.minXp, this.nextXp);
  String of(String lang) => lang == 'en' ? en : mr;
}

const _levels = [
  (0, 'उमेदवार', 'Candidate'),
  (300, 'अभ्यासू', 'Scholar'),
  (1500, 'योद्धा', 'Warrior'),
  (5000, 'विजेता', 'Champion'),
  (12000, 'अधिकारी', 'Officer'),
];

class CardState {
  double ease;
  int interval;
  int due;
  int reps;
  CardState({this.ease = 2.5, this.interval = 0, required this.due, this.reps = 0});
  Map<String, dynamic> toJson() => {'e': ease, 'i': interval, 'd': due, 'r': reps};
  factory CardState.fromJson(Map<String, dynamic> j) =>
      CardState(ease: (j['e'] as num).toDouble(), interval: j['i'], due: j['d'], reps: j['r']);
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
  String lang = 'mr';
  String? examId;
  int dailyGoal = 20;
  DateTime? examDate;
  String theme = 'system';
  bool reminders = true;
  int reminderHour = 7;

  // Gamification
  int xp = 0;
  int streak = 0;
  int bestStreak = 0;
  int lastActiveDay = 0;
  int freezeTokens = 0;
  bool comeback = false;
  int bestSpeed = 0;
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
    _file = File('${(await getApplicationSupportDirectory()).path}/progress.json');
    if (!await _file!.exists()) return;
    try {
      _fromJson(jsonDecode(await _file!.readAsString()));
    } catch (_) {
      // Keep defaults if the file is unreadable; never crash on startup.
    }
  }

  void _fromJson(Map<String, dynamic> j) {
    onboarded = j['onboarded'] ?? false;
    lang = j['lang'] ?? 'mr';
    examId = j['examId'];
    dailyGoal = j['dailyGoal'] ?? 20;
    examDate = j['examDate'] != null ? DateTime.tryParse(j['examDate']) : null;
    theme = j['theme'] ?? 'system';
    reminders = j['reminders'] ?? true;
    reminderHour = j['reminderHour'] ?? 7;
    xp = j['xp'] ?? 0;
    streak = j['streak'] ?? 0;
    bestStreak = j['bestStreak'] ?? 0;
    lastActiveDay = j['lastActiveDay'] ?? 0;
    freezeTokens = j['freezeTokens'] ?? 0;
    bestSpeed = j['bestSpeed'] ?? 0;
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
        'examId': examId,
        'dailyGoal': dailyGoal,
        'examDate': examDate?.toIso8601String(),
        'theme': theme,
        'reminders': reminders,
        'reminderHour': reminderHour,
        'xp': xp,
        'streak': streak,
        'bestStreak': bestStreak,
        'lastActiveDay': lastActiveDay,
        'freezeTokens': freezeTokens,
        'bestSpeed': bestSpeed,
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
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(_toJson()));
    await tmp.rename(f.path);
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

  int? get daysToExam {
    final d = examDate;
    if (d == null) return null;
    final n = dayIndex(d) - today();
    return n < 0 ? null : n;
  }

  int get totalAnswered => qStats.values.fold(0, (a, s) => a + s[0]);
  int get totalCorrect => qStats.values.fold(0, (a, s) => a + s[1]);
  double get accuracy => totalAnswered == 0 ? 0 : totalCorrect / totalAnswered;

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
    } else if (gap == 2 && freezeTokens > 0) {
      freezeTokens -= 1;
      streak += 1;
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

  void recordSpeed(int score) {
    if (score > bestSpeed) bestSpeed = score;
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
    xp = streak = bestStreak = lastActiveDay = freezeTokens = bestSpeed = 0;
    for (final c in [dayCounts, qStats, cards]) {
      c.clear();
    }
    mistakes.clear();
    bookmarks.clear();
    reported.clear();
    mocks.clear();
    onboarded = false;
    examId = null;
    lang = keepLang;
    save(now: true);
  }
}
