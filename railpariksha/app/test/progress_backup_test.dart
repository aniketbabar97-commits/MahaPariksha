import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/logic/progress_backup.dart';

void main() {
  _restoreGuards();
  test('backup blob round-trips the full progress state', () {
    final p = Progress()
      ..examId = 'rrb_ntpc'
      ..xp = 1234
      ..streak = 9
      ..dailyGoal = 30;
    p.reviewCard('c1', true);
    final blob = ProgressBackup.encode(p.toJson());
    expect(blob.length, lessThan(ProgressBackup.maxBlobBytes));
    final q = Progress()..restoreFrom(ProgressBackup.decode(blob));
    expect(q.examId, 'rrb_ntpc');
    expect(q.xp, p.xp);
    expect(q.streak, p.streak);
    expect(q.dailyGoal, 30);
    expect(q.cardsReviewedToday, 1);
  });

  test('a restore is only offered when the backup clearly has more', () {
    final local = Progress()..xp = 500;
    expect(ProgressBackup.isBetter(const BackupInfo(xp: 900, answered: 0, streak: 0, json: {}), local), isTrue);
    expect(ProgressBackup.isBetter(const BackupInfo(xp: 500, answered: 5, streak: 0, json: {}), local), isFalse);
    expect(ProgressBackup.isBetter(const BackupInfo(xp: 100, answered: 50, streak: 0, json: {}), local), isTrue);
  });
}

void _restoreGuards() {
  test('restoreFrom leaves local progress untouched when the backup is malformed', () {
    final p = Progress()..xp = 120..streak = 4..dailyGoal = 20;
    final ok = p.restoreFrom({'xp': 'not a number', 'dailyGoal': 'x'});
    expect(ok, isFalse);
    expect(p.xp, 120);
    expect(p.streak, 4);
    expect(p.dailyGoal, 20);
  });
  test('decode rejects a blob that inflates past the cap', () {
    final big = '{"pad":"${'a' * (ProgressBackup.maxInflatedBytes + 1024)}"}';
    final blob = base64Encode(gzip.encode(utf8.encode(big)));
    expect(() => ProgressBackup.decode(blob), throwsFormatException);
  });
}
