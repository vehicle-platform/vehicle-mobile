import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/services/alerts/alert_controller.dart';
import 'package:vehicle_mobile/services/alerts/alert_prefs.dart';
import 'package:vehicle_mobile/services/notifications/local_notifier.dart';
import 'package:vehicle_mobile/services/voice/intercom_audio.dart';
import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/ui/app_shell.dart';
import 'package:vehicle_mobile/ui/settings/alert_types_section.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/alert_banner.dart';

import 'support/fake_voice.dart';
import 'support/signed_in.dart';

Map<String, Object?> _alert(String event, {String cls = 'P1', bool speak = true}) => {
      'event': event,
      'id': 5,
      'rule_id': 'ALR-001',
      'class': cls,
      'severity': cls == 'P1' ? 'critical' : 'warning',
      'text': 'Coolant temperature high',
      'detail': 'Coolant 112 degC',
      'value': 112.0,
      'unit': 'degC',
      'device_id': 'bike-1',
      'ts': '2026-11-26T09:00:00.000Z',
      'speak': speak,
      'reason': event == 'clear' ? 'recovered' : null,
    };

String _sse(String event, Map<String, Object?> data) =>
    'event: $event\ndata: ${jsonEncode(data)}\n\n';

void main() {
  testWidgets(
      'the shell shows the alert banner on top, speaks it once in the active locale and hides it on clear',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final stream = StreamController<List<int>>();
    final store = signedInStore();
    final tts = FakeOutput()..instant = true;
    final voice = VoiceController(
      recognizer: FakeRecognizer(),
      output: tts,
      intercom: IntercomAudio(supported: false),
    );
    final alerts = AlertController(
      settingsStore: store,
      opener: (url, headers) async => stream.stream,
      onSpeak: (a) async => voice.speak('Warning. ${a.text}', force: true),
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppShell(
        settingsStore: store,
        voice: voice,
        alerts: alerts,
        localNotifier: const NoopLocalNotifier(),
        backgroundPull: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AlertBanner), findsNothing);

    stream.add(utf8.encode(_sse('alert', _alert('alert'))));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertBanner), findsOneWidget);
    expect(find.text('Coolant temperature high'), findsOneWidget);
    expect(find.text('112'), findsOneWidget);
    expect(tts.spoken, ['Warning. Coolant temperature high']);
    // Full width, at the very top, pushing the page AppBar down instead of covering it.
    final rect = tester.getRect(find.byType(AlertBanner));
    expect(rect.left, 0);
    expect(rect.width, 390);
    expect(rect.top, 0);
    final appBarRect = tester.getRect(find.byType(AppBar).first);
    expect(appBarRect.top, greaterThanOrEqualTo(rect.bottom));

    stream.add(utf8.encode(_sse('clear', _alert('clear'))));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertBanner), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await stream.close();
  });

  testWidgets('settings: a P1 type mutes only its voice, a P2 type can be hidden',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AlertPrefs.key: jsonEncode({
        'ALR-001': {'class': 'P1', 'text': 'Coolant temperature high', 'muted': false},
        'ALR-002': {'class': 'P2', 'text': 'Charging voltage low', 'muted': false},
      }),
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(body: SingleChildScrollView(child: AlertTypesSection())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Critical · Voice'), findsOneWidget);
    expect(find.text('Warning · Show'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('alert-type-ALR-001')));
    await tester.pumpAndSettle();
    final types = await const AlertPrefs().load();
    expect(types['ALR-001']!.muted, isTrue);
    expect(types['ALR-002']!.muted, isFalse);
  });
}
