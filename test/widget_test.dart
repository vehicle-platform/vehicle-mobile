import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_mobile/main.dart';

import 'support/signed_in.dart';

void main() {
  testWidgets('App shell shows the Live screen and the four destinations', (WidgetTester tester) async {
    // Phone width: the bottom navigation bar (width rule, below 600 px).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Cl250TelemetryApp(settingsStore: signedInStore()));
    await tester.pump();
    await tester.pump();

    // App bar title of the Live destination.
    expect(find.text('CL250 Telemetry'), findsOneWidget);

    // Navigation bar destinations.
    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    for (final label in ['Ride', 'Garage', 'Logbook', 'Assistant']) {
      expect(find.descendant(of: bar, matching: find.text(label)), findsOneWidget);
    }
    // Ride sub-navigation.
    for (final label in ['LIVE', 'SIGNALS', 'RECORD', 'DIAGNOSTICS']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // The removed brand badge and telematics form are gone.
    expect(find.text('HONDA'), findsNothing);
    expect(find.text('SYNC TO BIKE SCREEN'), findsNothing);

    // Tear the tree down so the store's tick timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Navigation switches between destinations', (WidgetTester tester) async {
    // Phone width: the bottom navigation bar (width rule, below 600 px).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Cl250TelemetryApp(settingsStore: signedInStore()));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('SIGNALS'));
    await tester.pump();
    expect(find.text('NO DATA'), findsWidgets);

    await tester.tap(find.text('DIAGNOSTICS'));
    await tester.pump();
    expect(find.text('LINK'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
