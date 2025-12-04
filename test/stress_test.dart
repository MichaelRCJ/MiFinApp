import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplicacion1/main.dart' as app;

void main() {
  group('Stress Tests', () {
    testWidgets('Rapid navigation stress test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Simulate rapid interactions
      for (int i = 0; i < 100; i++) {
        // Find and tap random elements
        final buttons = find.byType(ElevatedButton);
        if (buttons.evaluate().isNotEmpty) {
          await tester.tap(buttons.first);
          await tester.pump();
        }
        
        // Random scrolling
        await tester.fling(find.byType(Scrollable), Offset(0, 200), 1000);
        await tester.pump();
        
        // Navigate back randomly
        if (i % 10 == 0) {
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Memory stress test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Create many widgets rapidly
      for (int i = 0; i < 50; i++) {
        await tester.pump();
        await tester.pump(Duration(milliseconds: 16)); // 60 FPS
      }
    });
  });
}
