// This is a basic Flutter widget test for the Geotagging Camera app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotagging_camera/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GeotaggingCameraApp());

    // Verify that the app launches
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
