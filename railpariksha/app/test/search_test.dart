import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/core/app_scope.dart';
import 'package:railpariksha/core/purchases.dart';
import 'package:railpariksha/data/content_repo.dart';
import 'package:railpariksha/data/progress.dart';
import 'package:railpariksha/screens/search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a note whose topic is named by the query ranks above one that only mentions it', (tester) async {
    final repo = ContentRepo();
    await tester.runAsync(repo.load);
    final progress = Progress()
      ..lang = 'en'
      ..examId = 'rrb_ntpc';
    await tester.pumpWidget(AppScope(
      repo: repo,
      progress: progress,
      purchases: PurchaseManager(progress),
      child: const MaterialApp(home: SearchScreen()),
    ));
    await tester.enterText(find.byType(TextField), 'percentage');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    final named = find.textContaining('Mathematics · Percentage');
    expect(named, findsWidgets, reason: 'the Percentage note is found');
    final notes = find.textContaining(' · ');
    // The first note card listed is the one named after the query.
    final firstNote = tester.widgetList<Text>(notes).firstWhere((t) => (t.data ?? '').contains(' · ')).data!;
    expect(firstNote, contains('Percentage'));
    await tester.pump(const Duration(seconds: 1));
  });
}
