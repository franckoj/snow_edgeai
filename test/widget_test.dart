import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_sdk/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SnowEdgeApp());

    // Verify that app loads.
    expect(find.text('Snow Edge'), findsOneWidget);
  });
}
