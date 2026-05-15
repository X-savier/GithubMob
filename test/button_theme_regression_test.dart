// Regression tests for the global VxrTheme button styling.
//
// History: the theme used to set `minimumSize: Size.fromHeight(50)`
// for both `elevatedButtonTheme` and `outlinedButtonTheme`. That
// expanded to `Size(double.infinity, 50)`, which forced every
// `ElevatedButton`/`OutlinedButton` to demand infinite width and
// crashed layout (`BoxConstraints forces an infinite width`) whenever
// a button was placed inside a `Row`, `Wrap`, or any non-full-width
// parent. The fix is `Size(0, 50)` (height-only minimum) so buttons
// shrink-wrap horizontally by default while still meeting the 50px
// tap-height target.
//
// These tests guard against re-introducing that bug.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vxr_flutter/theme/vxr_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: VxrTheme.lightThemeData(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'ElevatedButton placed inside a Row does NOT force infinite width',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {},
                child: const Text('Create New Listing'),
              ),
            ],
          ),
        ),
      );

      // If the bug ever returns, the framework throws an assertion
      // during layout and `tester.takeException()` returns non-null.
      expect(tester.takeException(), isNull);

      // Sanity: the button rendered with a finite, modest width.
      final size = tester.getSize(find.byType(ElevatedButton));
      expect(size.width.isFinite, isTrue);
      expect(size.width, lessThan(800));
      // Height-only minimum is preserved.
      expect(size.height, greaterThanOrEqualTo(50));
    },
  );

  testWidgets(
    'OutlinedButton placed inside a Row does NOT force infinite width',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          Row(
            children: [
              OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () {}, child: const Text('Save')),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(OutlinedButton), findsNWidgets(2));
    },
  );

  testWidgets(
    'ElevatedButton in a Wrap renders multiple chips without overflow',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          Wrap(
            spacing: 8,
            children: List.generate(
              4,
              (i) => ElevatedButton(
                onPressed: () {},
                child: Text('Btn $i'),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ElevatedButton), findsNWidgets(4));
    },
  );

  testWidgets(
    'ElevatedButton wrapped in SizedBox(width: double.infinity) is still full-width',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Continue'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(ElevatedButton));
      // Full screen width on the default test view (800px logical).
      expect(size.width, greaterThan(600));
    },
  );
}
