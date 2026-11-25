import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vehicle_mobile/services/ble_service.dart';
import 'package:vehicle_mobile/services/notifications/notification_center.dart';
import 'package:vehicle_mobile/services/notifications/notification_sync.dart';
import 'package:vehicle_mobile/services/notifications_client.dart';
import 'package:vehicle_mobile/ui/diagnostics_screen.dart';
import 'package:vehicle_mobile/ui/live_screen.dart';
import 'package:vehicle_mobile/ui/notifications/notification_scope.dart';
import 'package:vehicle_mobile/ui/notifications/notifications_screen.dart';
import 'package:vehicle_mobile/ui/record_screen.dart';
import 'package:vehicle_mobile/ui/signals_screen.dart';
import 'package:vehicle_mobile/ui/telemetry/telemetry_store.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

import 'support/signed_in.dart';

Map<String, Object?> _note(int id, {bool read = false}) => {
      'id': id,
      'vehicle_id': 'veh-1',
      'kind': 'ride_summary',
      'severity': 'info',
      'title': 'Title $id',
      'body': 'Body $id',
      'session_id': null,
      'fault_id': null,
      'created_utc': DateTime.now().toUtc().toIso8601String(),
      'read': read,
    };

NotificationCenter _center({int status = 200}) {
  final items = [_note(1), _note(2), _note(3, read: true)];
  return NotificationCenter(
    pollInterval: const Duration(hours: 1),
    sync: NotificationSync(
      settingsStore: signedInStore(),
      client: NotificationsClient(httpClient: MockClient((req) async {
        if (status != 200) return http.Response('nf', status);
        if (req.method == 'POST') return http.Response('', 204);
        return http.Response(
            jsonEncode({'notifications': items, 'latest_id': items.length}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      })),
    ),
  );
}

typedef _Tab = ({String name, Widget Function(TelemetryStore) build});

final List<_Tab> _tabs = [
  (
    name: 'Live',
    build: (s) =>
        LiveScreen(store: s, bleService: BleService(), onOpenRecord: () {})
  ),
  (name: 'Signals', build: (s) => SignalsScreen(store: s)),
  (name: 'Record', build: (s) => RecordScreen(bleService: BleService())),
  (name: 'Diagnostics', build: (s) => DiagnosticsScreen(store: s)),
];

Future<void> _pump(
    WidgetTester tester, _Tab tab, NotificationCenter center) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = TelemetryStore();
  addTearDown(store.dispose);
  addTearDown(center.dispose);
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: NotificationScope(
          center: center, onAsk: (_, __) {}, child: tab.build(store)),
    ));
    center.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
  await tester.pump();
}

void main() {
  late Directory tmp;

  setUp(() {
    // Record reads its own settings and sessions folder: no keystore, a temp dir.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null);
    tmp = Directory.systemTemp.createTempSync('vehicle_bell_test_');
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tmp.path);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  for (final tab in _tabs) {
    group('${tab.name} tab bell', () {
      testWidgets('shows the unread badge and opens the inbox', (tester) async {
        await _pump(tester, tab, _center());
        expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byIcon(Icons.notifications_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(NotificationsScreen), findsOneWidget);
        expect(find.text('Title 2'), findsOneWidget);
      });

      testWidgets('is hidden when the server has no /notifications',
          (tester) async {
        await _pump(tester, tab, _center(status: 404));
        expect(find.byIcon(Icons.notifications_outlined), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
