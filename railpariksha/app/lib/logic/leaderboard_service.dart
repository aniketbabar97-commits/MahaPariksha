import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// One scored row on an exam's weekly leaderboard.
class LeaderboardEntry {
  final String deviceId;
  final String name;
  final double score;
  final int total;
  const LeaderboardEntry({required this.deviceId, required this.name, required this.score, required this.total});

  factory LeaderboardEntry.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) => LeaderboardEntry(
        deviceId: d.id,
        name: (d.data()['name'] as String?) ?? '?',
        score: (d.data()['score'] as num).toDouble(),
        total: (d.data()['total'] as num).toInt(),
      );
}

/// Anonymous, per-exam, weekly-reset leaderboard backed by Firestore -- device id +
/// a chosen display name, no real accounts. Entirely optional: every method is a
/// no-op/empty-result when Firebase isn't configured (no `google-services.json` at
/// build time, or init failed at launch -- see main.dart), so this never blocks the
/// app's offline-first core. See firestore.rules at the repo root for the write-shape
/// validation; there is no Firebase Auth here, so rules can validate shape but not
/// "this write really came from that device" -- an accepted V1 limitation.
class LeaderboardService {
  static bool get available => Firebase.apps.isNotEmpty;

  /// ISO-8601 week id (e.g. "2026-W40"), the same week for every day Mon-Sun --
  /// this is literally the Firestore path component the leaderboard resets on.
  static String weekId([DateTime? at]) {
    final d = (at ?? DateTime.now()).toUtc();
    // ISO week date algorithm: shift to the Thursday of this week, then count
    // weeks from that year's first Thursday.
    final thursday = d.add(Duration(days: 3 - ((d.weekday - 1) % 7)));
    final firstThursday = DateTime.utc(thursday.year, 1, 4);
    final week = 1 + ((thursday.difference(firstThursday).inDays) / 7).floor();
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  static CollectionReference<Map<String, dynamic>> _entries(String examId) => FirebaseFirestore.instance
      .collection('leaderboards')
      .doc(examId)
      .collection('weeks')
      .doc(weekId())
      .collection('entries');

  /// Submits [score] for this device/exam this week, keeping only the best score seen
  /// (a worse retry never overwrites a better earlier one). Silently does nothing when
  /// the leaderboard is unavailable or the write fails (e.g. offline) -- a failed
  /// leaderboard submission must never surface as an error to the user.
  static Future<void> submitScore({
    required String examId,
    required String deviceId,
    required String name,
    required double score,
    required int total,
  }) async {
    if (!available) return;
    try {
      final ref = _entries(examId).doc(deviceId);
      final existing = await ref.get();
      final prevScore = existing.data()?['score'] as num?;
      if (prevScore != null && prevScore >= score) return;
      await ref.set({'name': name, 'score': score, 'total': total, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Best-effort only.
    }
  }

  static Future<List<LeaderboardEntry>> top({required String examId, int limit = 20}) async {
    if (!available) return const [];
    try {
      final q = await _entries(examId).orderBy('score', descending: true).limit(limit).get();
      return q.docs.map(LeaderboardEntry.fromDoc).toList();
    } catch (_) {
      return const [];
    }
  }

  /// This device's rank this week (1-based), or null if it hasn't scored yet or the
  /// leaderboard is unavailable. Not cheap at large scale (counts every higher score),
  /// but is more than fine for this app's expected volume.
  static Future<int?> myRank({required String examId, required String deviceId}) async {
    if (!available) return null;
    try {
      final mine = await _entries(examId).doc(deviceId).get();
      final myScore = mine.data()?['score'] as num?;
      if (myScore == null) return null;
      final higher = await _entries(examId).where('score', isGreaterThan: myScore).count().get();
      return (higher.count ?? 0) + 1;
    } catch (_) {
      return null;
    }
  }
}
