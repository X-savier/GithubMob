// End-to-end smoke test for ViewXRent.
//
// Runs the real app entry point against an attached device or emulator
// and verifies the landing surface, then walks into the login screen.
//
// Run with:
//   flutter test integration_test/app_smoke_test.dart
//
// The full app initialises Supabase in `main()`, so this test
// requires real network access and an emulator/device. It does
// NOT attempt to sign in (which would require seeded credentials);
// for a richer flow add a follow-up test that types into the email
// and password fields using `dart-define`d test credentials.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:vxr_flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots to LandingPage and navigates to Login', (
    WidgetTester tester,
  ) async {
    app.main();
    // The real `main()` is async (awaits Supabase.initialize) — settle
    // until first frames are painted.
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Landing surface
    expect(find.text('Find Rental Homes\nMade Easy'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    // Tap "Get Started" → Login screen
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Login screen typically exposes email + password TextFields.
    expect(find.byType(TextField), findsWidgets);
  });
}
