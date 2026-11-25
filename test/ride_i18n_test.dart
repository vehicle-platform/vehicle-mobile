import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/models/gps_block.dart';
import 'package:vehicle_mobile/models/telemetry_data.dart';
import 'package:vehicle_mobile/services/ble_service.dart';
import 'package:vehicle_mobile/ui/diagnostics_screen.dart';
import 'package:vehicle_mobile/ui/live_screen.dart';
import 'package:vehicle_mobile/ui/record_screen.dart';
import 'package:vehicle_mobile/ui/signals_screen.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/telemetry/telemetry_store.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

Widget _host(Widget child, Locale locale) => MaterialApp(
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

TelemetryData _packet() => TelemetryData(
      packetVersion: TelemetryVersion.v4,
      deviceTimeMs: 1,
      rpm: 3500,
      speed: 62,
      coolantTemp: 88,
      throttlePos: 17,
      batteryVolt: 13.8,
      leanAngle: null,
      maxLeanRight: null,
      maxLeanLeft: null,
      rpmValid: true,
      speedValid: true,
      coolantTempValid: true,
      throttlePosValid: true,
      batteryVoltValid: true,
      leanValid: false,
      ecuPresent: true,
      imuActive: true,
      canBusState: CanBusState.running,
    );

void main() {
  const en = Locale('en');
  const tr = Locale('tr');

  testWidgets('Live screen has no title and shows readouts in English and Turkish',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = TelemetryStore();
    addTearDown(store.dispose);
    store.updateConnection(true, deviceName: 'Test-Bike');
    store.updateTelemetry(_packet());
    final live = LiveScreen(store: store, bleService: BleService(), onOpenRecord: () {});

    await tester.pumpWidget(_host(live, en));
    expect(find.text('ECU present'), findsOneWidget);
    expect(find.text('CL250 Telemetry'), findsNothing);
    expect(find.text('62'), findsOneWidget);
    expect(find.text('km/h'), findsOneWidget);

    await tester.pumpWidget(_host(live, tr));
    await tester.pump();
    expect(find.text('ECU var'), findsOneWidget);
    expect(find.text('ECU present'), findsNothing);
    expect(find.text('OTURUM KAYDET'), findsOneWidget);
  });

  testWidgets('Signals and Diagnostics follow the locale and carry no title',
      (tester) async {
    final store = TelemetryStore();
    addTearDown(store.dispose);
    store.updateConnection(true, deviceName: 'Test-Bike');
    store.updateTelemetry(_packet());

    await tester.pumpWidget(_host(SignalsScreen(store: store), tr));
    await tester.pump();
    expect(find.text('Sinyaller'), findsNothing);
    expect(find.text('Tümü'), findsOneWidget);
    expect(find.text('CANLI'), findsWidgets);

    await tester.pumpWidget(_host(DiagnosticsScreen(store: store), tr));
    await tester.pump();
    expect(find.text('BAĞLANTI'), findsOneWidget);
    expect(find.text('Paketler'.toUpperCase()), findsOneWidget);
    expect(find.text('Diagnostics'), findsNothing);
  });

  test('link status text is English by default and localizable', () {
    final trL = lookupAppLocalizations(tr);
    expect(canStateStatus(CanBusState.busOff).text, 'CAN bus-off');
    expect(canStateStatus(CanBusState.running, trL).text, 'CAN çalışıyor');
    expect(canStateStatus(null, trL).text, 'CAN yok');
    expect(gpsStatus(const GpsLinkStatus(GpsLinkState.notOffered), null).text, 'GPS not offered');
  });

  test('vehicle-signal status line is localized', () {
    const line = VehicleSignalStatusLine(
        connected: false, latest: {}, blockCount: 0, lostBlocks: 0);
    expect(line.label, 'Vehicle signals: no data');
    expect(line.labelFor(lookupAppLocalizations(tr)), 'Araç sinyalleri: veri yok');
  });

  testWidgets('Record screen has no title but keeps its tabs', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(RecordScreen(bleService: BleService()), tr));
    await tester.pump();
    expect(find.text('Kayıt'), findsOneWidget); // tab only, no duplicate title
    expect(find.text('Oturumlar'), findsOneWidget);
    expect(find.text('KAYDI BAŞLAT'), findsOneWidget);
  });
}
