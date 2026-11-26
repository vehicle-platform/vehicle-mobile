import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/services/notifications/local_notifier.dart';
import 'package:vehicle_mobile/services/voice/intercom_audio.dart';
import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/ui/app_shell.dart';
import 'package:vehicle_mobile/ui/assistant/assistant_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

import 'support/fake_voice.dart';

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

  testWidgets('1280 px: Logbook shows list and an empty detail pane',
      (tester) async {
    await _pump(tester, 1280);
    await tester.tap(find.descendant(
        of: find.byType(NavigationRail), matching: find.text('Logbook')));
    await tester.pumpAndSettle();
    expect(find.text('Select a ride to see its details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('900 px: single panes without the detail placeholder',
      (tester) async {
    await _pump(tester, 700);
    await tester.tap(find.descendant(
        of: find.byType(NavigationRail), matching: find.text('Logbook')));
    await tester.pumpAndSettle();
    expect(find.text('Select a ride to see its details'), findsNothing);
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

  testWidgets('the shell gives the voice the speech language of the app',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final voice = VoiceController(
      recognizer: FakeRecognizer(),
      output: FakeOutput(),
      intercom: IntercomAudio(supported: false),
    );
    Future<void> pumpWith(Locale locale) => tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AppShell(
              voice: voice,
              localNotifier: const NoopLocalNotifier(),
              backgroundPull: false),
        ));
    await pumpWith(const Locale('en'));
    await tester.pumpAndSettle();
    expect(voice.localeTag, 'en-US');
    await pumpWith(const Locale('tr'));
    await tester.pumpAndSettle();
    expect(voice.localeTag, 'tr-TR');
  });
}
