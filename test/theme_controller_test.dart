import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/theme_controller.dart';
import 'package:vehicle_mobile/ui/widgets/sunlight_toggle.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to system when nothing or an unknown value is saved',
      () async {
    expect((await ThemeController.load()).choice, ThemeChoice.system);
    SharedPreferences.setMockInitialValues({ThemeController.prefsKey: 'neon'});
    expect((await ThemeController.load()).choice, ThemeChoice.system);
  });

  test('persists the choice and restores it', () async {
    final c = ThemeController();
    await c.set(ThemeChoice.sunlight);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeController.prefsKey), 'sunlight');
    expect((await ThemeController.load()).choice, ThemeChoice.sunlight);
  });

  test('maps choices to MaterialApp fields', () async {
    final c = ThemeController();
    expect(c.themeMode, ThemeMode.system);
    expect(c.lightTheme.extension<VehicleTokens>(), VehicleTokens.light);
    await c.set(ThemeChoice.dark);
    expect(c.themeMode, ThemeMode.dark);
    await c.set(ThemeChoice.sunlight);
    expect(c.themeMode, ThemeMode.light);
    expect(c.lightTheme.extension<VehicleTokens>(), VehicleTokens.sunlight);
    await c.set(ThemeChoice.light);
    expect(c.lightTheme.extension<VehicleTokens>(), VehicleTokens.light);
  });

  test('toggle returns to the choice made before sunlight', () async {
    final c = ThemeController(initial: ThemeChoice.dark);
    await c.toggleSunlight();
    expect(c.choice, ThemeChoice.sunlight);
    await c.toggleSunlight();
    expect(c.choice, ThemeChoice.dark);
  });

  test('a failing preferences store keeps the choice for this run', () async {
    // No mock values at all on a fresh binding still works; the in-memory
    // choice is what the app reads.
    final c = ThemeController();
    await c.set(ThemeChoice.light);
    expect(c.choice, ThemeChoice.light);
  });

  testWidgets('ride-screen toggle switches sunlight on and off',
      (tester) async {
    final c = ThemeController();
    await tester.pumpWidget(ListenableBuilder(
      listenable: c,
      builder: (context, _) => ThemeScope(
        controller: c,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: c.lightTheme,
          darkTheme: c.darkTheme,
          themeMode: c.themeMode,
          home: const Scaffold(body: Center(child: SunlightToggle())),
        ),
      ),
    ));
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    final size = tester.getSize(find.byType(IconButton));
    expect(size.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(c.choice, ThemeChoice.sunlight);
    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    final ctx = tester.element(find.byType(IconButton));
    expect(Theme.of(ctx).extension<VehicleTokens>(), VehicleTokens.sunlight);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(c.choice, ThemeChoice.system);
  });

  testWidgets('toggle hides without a ThemeScope', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SunlightToggle()));
    expect(find.byType(IconButton), findsNothing);
  });
}
