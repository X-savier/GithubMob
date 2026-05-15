// Widget tests for the public, framework-only UI of the app.
//
// We deliberately pump `LandingPage` directly (wrapped in a minimal
// MaterialApp using the real theme) instead of `MyApp`. `MyApp` calls
// `Supabase.instance` from `initState`, which throws when the platform
// channels aren't bound in the test harness.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vxr_flutter/main.dart';
import 'package:vxr_flutter/theme/vxr_theme.dart';
import 'package:vxr_flutter/theme/vxr_widgets.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: VxrTheme.lightThemeData(),
    builder: (context, c) => VxrTheme(child: c!),
    home: child,
  );
}

Future<void> _pumpAsPhone(WidgetTester tester, Widget app) async {
  // LandingPage is designed for a phone aspect ratio; the default
  // 800x600 test viewport otherwise overflows the bottom CTA panel.
  tester.view.physicalSize = const Size(1170, 2532); // iPhone 14 Pro
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
}

void main() {
  testWidgets('LandingPage renders headline and CTA buttons', (
    WidgetTester tester,
  ) async {
    await _pumpAsPhone(tester, _wrapWithTheme(const LandingPage()));

    // Headline copy (multi-line)
    expect(find.text('Find Rental Homes\nMade Easy'), findsOneWidget);

    // Primary + secondary CTA labels
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('LandingPage exposes Vxr primary + secondary buttons', (
    WidgetTester tester,
  ) async {
    await _pumpAsPhone(tester, _wrapWithTheme(const LandingPage()));

    // Surface check — Get Started uses VxrPrimaryButton, Create Account
    // uses VxrSecondaryButton.
    expect(find.byType(VxrPrimaryButton), findsOneWidget);
    expect(find.byType(VxrSecondaryButton), findsOneWidget);
  });
}
