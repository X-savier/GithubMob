import 'package:flutter_test/flutter_test.dart';
import 'package:vxr_flutter/main.dart';

void main() {
  testWidgets('Landing page loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('ViewxRent'), findsOneWidget);
    expect(find.text('Find Rental Homes\nMade Easy'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
