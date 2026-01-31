// Basic Flutter widget test for Call Paul phone app.
//
// To run: flutter test test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:call_paul/main.dart';

void main() {
  testWidgets('Call Paul app builds and shows home content', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CallPaulApp());

    // Verify app bar title.
    expect(find.text('Call Paul'), findsOneWidget);

    // Verify main home screen text (Group 1 – Smartphone app).
    expect(find.text('Group 1 – Smartphone app'), findsOneWidget);

    // Verify subtext.
    expect(find.text('Fake call • AI scripts • n8n SOS'), findsOneWidget);
  });
}
