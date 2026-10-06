import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/logic/progress_backup.dart';

void main() {
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
