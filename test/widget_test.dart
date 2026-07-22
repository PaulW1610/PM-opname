// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:photo_organizer_app/main.dart';

void main() {
  testWidgets('StartScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // Namen zoals ze sinds de huisstijlwijziging van 20 juli 2026 in beeld
    // staan; de test bleef hangen op de oude naam en faalde daardoor.
    expect(find.text('blueprint collective'), findsWidgets);
    expect(find.text('Adres ophalen'), findsWidgets);
  });
}
