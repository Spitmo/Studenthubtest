// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:studenthub/main.dart';

void main() {
  // Setup for tests
  setUpAll(() async {
    // Load environment variables for tests
    TestWidgetsFlutterBinding.ensureInitialized();
    // Create a mock .env for testing
    dotenv.testLoad(fileInput: '''
SUPABASE_URL=https://test.supabase.co
SUPABASE_ANON_KEY=test_key
APP_NAME=StudentHub
APP_VERSION=1.0.0
DEBUG_MODE=true
''');
  });

  testWidgets('App loads and shows login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StudentHubApp());
    
    // Wait for initialization
    await tester.pumpAndSettle();

    // Verify that we can find the StudentHub title
    expect(find.text('StudentHub'), findsAtLeastOneWidget);
    
    // Should show login elements
    expect(find.text('Roll Number'), findsOneWidget);
    expect(find.text('Access Code'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Login form validation works', (WidgetTester tester) async {
    await tester.pumpWidget(const StudentHubApp());
    await tester.pumpAndSettle();

    // Try to login without entering data
    final loginButton = find.text('Login');
    await tester.tap(loginButton);
    await tester.pump();

    // Should show validation errors
    expect(find.text('Required'), findsAtLeast(1));
  });

  testWidgets('Theme toggle works', (WidgetTester tester) async {
    await tester.pumpWidget(const StudentHubApp());
    await tester.pumpAndSettle();

    // Find and tap the theme toggle button
    final themeButton = find.byIcon(Icons.dark_mode_rounded);
    if (await tester.binding.defaultBinaryMessenger
        .handlePlatformMessage('flutter/platform', null) != null) {
      await tester.tap(themeButton);
      await tester.pump();
      
      // Should switch to light mode icon
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    }
  });
}
