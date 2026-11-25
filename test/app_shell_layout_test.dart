import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/ui/app_shell.dart';
import 'package:vehicle_mobile/ui/settings_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

Widget _app() => MaterialApp(theme: buildAppTheme(), home: const AppShell());

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'without phone tabs (web, desktop) only Assistant, Rides, Faults and Settings show',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pump();

    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    for (final label in ['Asistan', 'Rides', 'Faults', 'Settings']) {
      expect(
          find.descendant(of: bar, matching: find.text(label)), findsOneWidget,
          reason: label);
    }
    for (final label in ['Live', 'Signals', 'Record', 'Diagnostics']) {
      expect(find.descendant(of: bar, matching: find.text(label)), findsNothing,
          reason: label);
    }
    // Opens on the assistant.
    expect(find.text('Merhaba, ben Sürüş Asistanı. Ne öğrenmek istersin?'), findsOneWidget);
  });

  testWidgets('a wide computer window uses a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.descendant(
        of: find.byType(NavigationRail), matching: find.text('Settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
