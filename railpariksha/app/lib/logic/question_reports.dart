import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Sends a student's "Report an error" to the owner. One small document per report in the
/// `reports` collection (create-only for clients, see firestore.rules; read it in the Firebase
/// Console). Best-effort and silent: no Firebase, offline, or rules not published all just mean the
/// report stays local (the question is still hidden on that phone).
class QuestionReports {
  static bool get available => Firebase.apps.isNotEmpty;

  /// Longest values the rules accept; trimmed here so a long question id or reason can't fail the write.
  static const maxId = 60;
  static const maxReason = 80;

  static Map<String, dynamic> payload({required String id, required String reason, required String lang, required bool pyq}) => {
        'qid': id.length > maxId ? id.substring(0, maxId) : id,
        'reason': reason.length > maxReason ? reason.substring(0, maxReason) : reason,
        'lang': lang == 'en' ? 'en' : 'hi',
        'pyq': pyq,
      };

  static Future<bool> send({required String id, required String reason, required String lang, required bool pyq}) async {
    if (!available) return false;
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .add({...payload(id: id, reason: reason, lang: lang, pyq: pyq), 'at': FieldValue.serverTimestamp()}).timeout(const Duration(seconds: 15));
      return true;
    } catch (_) {
      return false;
    }
  }
}
