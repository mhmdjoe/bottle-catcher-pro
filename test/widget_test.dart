import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/main.dart';

void main() {
  testWidgets('Game starts with a menu and start button', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BottleCatcherApp());

    // Verify that the start button is present
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('START GAME'), findsOneWidget);
  });
}
