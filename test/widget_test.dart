import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:urbaneye/main.dart';

void main() {
  testWidgets('UrbanEyeApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UrbanEyeApp());

    // Verify app renders without crashing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
