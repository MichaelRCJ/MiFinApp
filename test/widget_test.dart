import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplicacion1/main.dart';

void main() {
  testWidgets('Splash -> Login -> Home navigation works', (WidgetTester tester) async {
    await tester.pumpWidget(const ShinyApp());

    // Splash fades in
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Shiny'), findsOneWidget);

    // After ~1s it navigates to Login
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    expect(find.text('Shiny Inventory Manager'), findsOneWidget);

    // Tap Login button
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pump();

    // Home visible (bottom nav present)
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Inicio'), findsWidgets);
  });

  testWidgets('Dashboard quick actions switch tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const ShinyApp());

    // Move to Login then Home
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pump();

    // Tap quick action "Ingresos"
    await tester.tap(find.text('Ingresos').first);
    await tester.pump();
    expect(find.text('Ingresos'), findsWidgets);

    // Tap quick action "Gastos" via back to dashboard first
    // Navigate back to dashboard tab
    await tester.tap(find.text('Inicio').first);
    await tester.pump();
    await tester.tap(find.text('Gastos').first);
    await tester.pump();
    expect(find.text('Registros de gastos'), findsOneWidget);
  });
}
