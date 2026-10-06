import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/progress.dart';
import 'auth_service.dart';

/// A cloud copy of the student's progress tied to their Google sign-in, so a reinstall or a new
/// phone (common for this audience) doesn't cost them their streak, XP and mistake book.
///
/// One document per user, `users/{uid}/backup/progress`: gzip + base64 of the same JSON the app
/// saves locally, plus a few plain numbers so a restore can be offered without decoding. Firestore
/// rules in firestore.rules allow a user to read and write only their own document. Every call is
/// best-effort: not signed in, offline, rules not deployed, or over the 1 MiB document limit all
/// just mean "no backup this time".
class ProgressBackup {
  /// Firestore documents are capped at 1 MiB; leave headroom for the other fields.
  static const maxBlobBytes = 900 * 1024;

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final u = AuthService.currentUser;
    if (u == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(u.uid).collection('backup').doc('progress');
  }

  static String encode(Map<String, dynamic> json) => base64Encode(gzip.encode(utf8.encode(jsonEncode(json))));

  static Map<String, dynamic> decode(String blob) =>
      jsonDecode(utf8.decode(gzip.decode(base64Decode(blob)))) as Map<String, dynamic>;

  /// Uploads now. False when not signed in, too large, or the write failed.
  static Future<bool> upload(Progress p) async {
    final doc = _doc();
    if (doc == null) return false;
    try {
      final blob = encode(p.toJson());
      if (blob.length > maxBlobBytes) return false;
      await doc.set({
        'v': 1,
        'gz': blob,
        'xp': p.xp,
        'answered': p.totalAnswered,
        'streak': p.streak,
        'at': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 20));
      p.update((p) => p.backupDay = today());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// One upload a day, from app launch, for signed-in students. Fire-and-forget.
  static Future<void> uploadIfDue(Progress p) async {
    if (AuthService.currentUser == null || p.backupDay == today()) return;
    await upload(p);
  }

  /// The stored backup, or null when there is none (or it can't be read).
  static Future<BackupInfo?> fetch() async {
    final doc = _doc();
    if (doc == null) return null;
    try {
      final snap = await doc.get().timeout(const Duration(seconds: 20));
      final d = snap.data();
      if (d == null || d['gz'] is! String) return null;
      return BackupInfo(
        xp: (d['xp'] as num?)?.toInt() ?? 0,
        answered: (d['answered'] as num?)?.toInt() ?? 0,
        streak: (d['streak'] as num?)?.toInt() ?? 0,
        json: decode(d['gz'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether a backup clearly holds more progress than this phone: worth asking before overwriting
  /// local work, never silently.
  static bool isBetter(BackupInfo b, Progress local) => b.xp > local.xp || b.answered > local.totalAnswered + 10;
}

class BackupInfo {
  final int xp;
  final int answered;
  final int streak;
  final Map<String, dynamic> json;
  const BackupInfo({required this.xp, required this.answered, required this.streak, required this.json});
}
