import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:financify_v1/main.dart';
import 'package:financify_v1/frontend/providers/theme_provider.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Create and initialize the theme provider
    final themeProvider = ThemeProvider();
    // Note: We skip the initialize() call in tests as it might need actual storage
    
    // Build our app and trigger a frame with the required themeProvider.
    await tester.pumpWidget(
      MyApp(themeProvider: themeProvider),
    );

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}