import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/services/notifications/local_notifier.dart';
import 'package:vehicle_mobile/ui/app_shell.dart';
import 'package:vehicle_mobile/ui/assistant/assistant_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, double width, {Locale? locale}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    locale: locale ?? const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const AppShell(
        localNotifier: NoopLocalNotifier(), backgroundPull: false),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('390 px: bottom bar, no rail, header gear opens settings',
      (tester) async {
    await _pump(tester, 390);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('768 px: rail with single panes, no side panel or command key',
      (tester) async {
    await _pump(tester, 768);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // Settings lives on the rail, not in the header.
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1280 px: rail, Ctrl+K command bar and the assistant side panel',
      (tester) async {
    await _pump(tester, 1280);
    expect(find.byType(NavigationRail), findsOneWidget);

    // Open Garage, then the assistant panel appears beside it.
    await tester.tap(find.descendant(
        of: find.byType(NavigationRail), matching: find.text('Garage')));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantComposer), findsNothing);
    await tester.tap(find.byTooltip('Show assistant panel'));
    await tester.pumpAndSettle();
    final composer = tester.getRect(find.byType(AssistantComposer));
    expect(composer.right, closeTo(1280, 1));
    expect(composer.width, lessThanOrEqualTo(400));

    // Command bar.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Go to Logbook'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'logb');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.text('Go to Logbook'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Turkish locale names the assistant Sürüş Asistanı',
      (tester) async {
    await _pump(tester, 390, locale: const Locale('tr'));
    expect(
        find.descendant(
            of: find.byType(NavigationBar), matching: find.text('Asistan')),
        findsOneWidget);
    expect(find.text('Garaj'), findsOneWidget);
  });
}
