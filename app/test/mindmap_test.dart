import 'package:bharari/data/models.dart';
import 'package:bharari/screens/topic_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final map = MapNode(
    const Bi('भारतीय संविधान', 'Indian Constitution'),
    [
      MapNode(const Bi('इतिहास', 'History'), [
        MapNode(const Bi('26 नोव्हेंबर 1949 रोजी स्वीकारले', 'Adopted 26 Nov 1949'), const []),
      ]),
      MapNode(const Bi('प्रमुख व्यक्ती', 'Key people'), [
        MapNode(const Bi('डॉ. आंबेडकर - मसुदा समिती', 'Dr. Ambedkar - Drafting Committee'), const []),
      ]),
    ],
  );

  Widget host() => MaterialApp(home: Scaffold(body: MindMapView(root: map, lang: 'mr')));

  testWidgets('branch leaves are hidden until the branch is tapped open', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('इतिहास'), findsOneWidget);
    expect(find.textContaining('26 नोव्हेंबर 1949'), findsNothing);

    await tester.tap(find.text('इतिहास'));
    await tester.pumpAndSettle();

    expect(find.textContaining('26 नोव्हेंबर 1949'), findsOneWidget);
    // The second branch stays collapsed independently.
    expect(find.textContaining('डॉ. आंबेडकर'), findsNothing);
  });

  testWidgets('tapping an open branch collapses it again', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('इतिहास'));
    await tester.pumpAndSettle();
    expect(find.textContaining('26 नोव्हेंबर 1949'), findsOneWidget);

    await tester.tap(find.text('इतिहास'));
    await tester.pumpAndSettle();
    expect(find.textContaining('26 नोव्हेंबर 1949'), findsNothing);
  });

  testWidgets('Expand all opens every branch, and the label switches to Collapse all', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('सर्व उघडा'));
    await tester.pumpAndSettle();

    expect(find.textContaining('26 नोव्हेंबर 1949'), findsOneWidget);
    expect(find.textContaining('डॉ. आंबेडकर'), findsOneWidget);
    expect(find.text('सर्व बंद करा'), findsOneWidget);
  });

  testWidgets('switching language relabels nodes without changing structure', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MindMapView(root: map, lang: 'en'))));
    expect(find.text('History'), findsOneWidget);
    expect(find.text('इतिहास'), findsNothing);
  });
}
