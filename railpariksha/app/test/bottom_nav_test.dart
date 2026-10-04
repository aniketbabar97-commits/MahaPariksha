import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/widgets/bottom_nav.dart';

void main() {
  const labels = [
    ['Today', 'Practice', 'Revise', 'Progress', 'Me'],
    ['आज', 'अभ्यास', 'रिवीज़न', 'प्रगति', 'मैं'],
  ];

  // Every tab, selected in turn, on a small phone with large text: no overflow, label stays inside the bar.
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final set in labels) {
        testWidgets('nav labels fit at ${width}dp x$scale (${set.first})', (tester) async {
          tester.view.physicalSize = Size(width * 3, 740 * 3);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          for (var sel = 0; sel < set.length; sel++) {
            await tester.pumpWidget(MaterialApp(
              builder: (c, child) => MediaQuery(
                  data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
              home: Scaffold(
                bottomNavigationBar: RpBottomNav(
                  index: sel,
                  onTap: (_) {},
                  items: [for (final l in set) NavItem(Icons.circle_outlined, Icons.circle, l)],
                ),
              ),
            ));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'overflow with ${set[sel]} selected');
          }
        });
      }
    }
  }
}
