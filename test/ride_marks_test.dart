import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/models/ride_mark.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/ble_service.dart';
import 'package:vehicle_mobile/services/mark_queue.dart';
import 'package:vehicle_mobile/services/marks_client.dart';
import 'package:vehicle_mobile/services/ride_client.dart';
import 'package:vehicle_mobile/ui/live_screen.dart';
import 'package:vehicle_mobile/ui/rides/ride_summary_screen.dart';
import 'package:vehicle_mobile/ui/telemetry/telemetry_store.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

class _MemorySecrets implements SecretStore {
  _MemorySecrets([this.token]);

  String? token;

  @override
  Future<String?> read(String key) async => token;

  @override
  Future<void> write(String key, String value) async {
    token = value;
  }

  @override
  Future<void> delete(String key) async {
    token = null;
  }
}

Widget _appHost(Widget child, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      home: child,
    );

AppSettingsStore _settingsStore(String? baseUrl, String? token) {
  SharedPreferences.setMockInitialValues({
    if (baseUrl != null) 'settings.server_base_url': baseUrl,
  });
  return AppSettingsStore(secrets: _MemorySecrets(token));
}

Map<String, Object?> _summaryFixture() => {
      'session_id': '20261116-090000-d83e',
      'ride_definition': 'cl250_ride.yaml',
      'defs_version': '0.33.0',
      'signals': [
        {
          'name': 'ride_time',
          'status': 'computed',
          'unit': 's',
          'range': [0, 7200],
          'kind': 'scalar',
          'value': 1200,
          'flag': null,
        },
      ],
    };

void main() {
  test('RideMark serialization omits position fields and round-trips cleanly',
      () {
    const mark = RideMark(
      id: 'm_1700000000000_abcdef',
      tUtcMs: 1700000000000,
      kind: RideMarkKind.warningLight,
      note: 'MIL flashed briefly',
    );
    final wire = mark.toJson();
    expect(wire, {
      'id': 'm_1700000000000_abcdef',
      't_utc': 1700000000000,
      'kind': 'warning_light',
      'note': 'MIL flashed briefly',
    });
    expect(wire.containsKey('lat'), isFalse);
    expect(wire.containsKey('lon'), isFalse);
    expect(wire.containsKey('position'), isFalse);

    final parsed = RideMark.fromJson(wire);
    expect(parsed, isNotNull);
    expect(parsed!.id, mark.id);
    expect(parsed.tUtcMs, mark.tUtcMs);
    expect(parsed.kind, RideMarkKind.warningLight);
    expect(parsed.note, 'MIL flashed briefly');
  });

  test('MarkQueue queues offline, deduplicates by id, and retries on flush',
      () async {
    final settings = _settingsStore('http://127.0.0.1:8000', 'tok');
    var online = false;
    final postedIds = <String>[];

    final client = MarksClient(
      httpClient: MockClient((request) async {
        if (!online) {
          throw http.ClientException('offline');
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        postedIds.add(body['id'] as String);
        return http.Response(jsonEncode(body), 201);
      }),
    );

    final queue = MarkQueue(
      client: client,
      settingsStore: settings,
      clock: () => DateTime.utc(2026, 11, 16, 9, 5),
      random: Random(42),
    );
    addTearDown(queue.dispose);

    const m1 = RideMark(
      id: 'dup-id-1',
      tUtcMs: 1794819900000,
      kind: RideMarkKind.vibration,
    );
    const m2 = RideMark(
      id: 'mark-id-2',
      tUtcMs: 1794819960000,
      kind: RideMarkKind.misfire,
    );

    // Offline enqueue persists and does not deliver yet.
    expect(await queue.enqueue(m1), isFalse);
    // Duplicate id is dropped instead of queued twice.
    expect(await queue.enqueue(m1), isFalse);
    expect(await queue.enqueue(m2), isFalse);
    expect((await queue.pending()).map((m) => m.id).toList(),
        ['dup-id-1', 'mark-id-2']);
    expect(queue.pendingCount.value, 2);
    expect(postedIds, isEmpty);

    // Back online: flush delivers both in order and empties the queue.
    online = true;
    expect(await queue.flush(), 2);
    expect(postedIds, ['dup-id-1', 'mark-id-2']);
    expect(await queue.pending(), isEmpty);
    expect(queue.pendingCount.value, 0);
  });

  testWidgets(
      'LiveScreen Mark button opens 5-kind quick picker, records mark, and auto-closes',
      (tester) async {
    final settings = _settingsStore('http://127.0.0.1:8000', 'tok');
    final posted = <Map<String, dynamic>>[];
    final client = MarksClient(
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        posted.add(body);
        return http.Response(jsonEncode(body), 201);
      }),
    );
    final queue = MarkQueue(
      client: client,
      settingsStore: settings,
      clock: () => DateTime.utc(2026, 11, 16, 9, 10),
      random: Random(7),
    );
    final store = TelemetryStore();
    addTearDown(() {
      queue.dispose();
      store.dispose();
    });

    await tester.pumpWidget(
      _appHost(
        LiveScreen(
          store: store,
          bleService: BleService(),
          onOpenRecord: () {},
          markQueue: queue,
          pickerTimeout: const Duration(seconds: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Large glove-friendly Mark button is visible and at least 64 px tall.
    final markButton = find.byKey(const ValueKey('live-mark-button'));
    expect(markButton, findsOneWidget);
    expect(tester.getSize(markButton).height, greaterThanOrEqualTo(64));

    // Tap Mark -> picker shows 4 common kinds + other (5 total).
    await tester.ensureVisible(markButton);
    await tester.tap(markButton);
    await tester.pumpAndSettle();
    for (final kind in RideMarkKind.quickPickerKinds) {
      expect(find.byKey(ValueKey('mark-kind-${kind.wireName}')), findsOneWidget);
    }

    // Wait past auto-close timeout -> picker closes itself with no mark posted.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mark-kind-misfire')), findsNothing);
    expect(posted, isEmpty);

    // Open again and pick Misfire -> sends POST /marks and shows confirmation.
    await tester.tap(markButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mark-kind-misfire')));
    await tester.pumpAndSettle();
    expect(posted, hasLength(1));
    expect(posted.single['kind'], 'misfire');
    expect(posted.single['t_utc'],
        DateTime.utc(2026, 11, 16, 9, 10).millisecondsSinceEpoch);
    expect(find.text('Marked: Misfire'), findsOneWidget);
  });

  testWidgets(
      'RideSummaryScreen lists ride marks, deletes a mark, and surfaces delete errors',
      (tester) async {
    final settings = _settingsStore('http://127.0.0.1:8000', 'tok');
    final rideClient = RideClient(
      httpClient: MockClient((request) async {
        if (request.url.path.contains('summary')) {
          return http.Response(jsonEncode(_summaryFixture()), 200);
        }
        return http.Response(jsonEncode({'session_id': '20261116-090000-d83e'}),
            200);
      }),
    );

    final deleted = <String>[];
    var failDelete = false;
    final marksClient = MarksClient(
      httpClient: MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/marks')) {
          return http.Response(
            jsonEncode({
              'ride_id': '20261116-090000-d83e',
              'start_utc_ms': 1794819600000,
              'end_utc_ms': 1794820800000,
              'marks': [
                {
                  'id': 'm-1',
                  't_utc': 1794819660000,
                  'kind': 'vibration',
                  'note': 'buzz near 5k',
                },
                {
                  'id': 'm-2',
                  't_utc': 1794819720000,
                  'kind': 'noise',
                  'note': null,
                },
              ],
            }),
            200,
          );
        }
        if (request.method == 'DELETE') {
          if (failDelete) {
            return http.Response(jsonEncode({'detail': 'server error'}), 500);
          }
          deleted.add(request.url.pathSegments.last);
          return http.Response('', 204);
        }
        return http.Response('', 404);
      }),
    );

    await tester.pumpWidget(
      _appHost(
        RideSummaryScreen(
          sessionId: '20261116-090000-d83e',
          settingsStore: settings,
          client: rideClient,
          marksClient: marksClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll to Ride marks section and verify both marks appear.
    await tester.scrollUntilVisible(
      find.text('buzz near 5k'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Vibration'), findsOneWidget);
    expect(find.text('buzz near 5k'), findsOneWidget);
    expect(find.text('Noise'), findsOneWidget);

    // Delete m-1 -> DELETE /marks/m-1 called and row removed.
    await tester.ensureVisible(find.byKey(const ValueKey('delete-mark-m-1')));
    await tester.tap(find.byKey(const ValueKey('delete-mark-m-1')));
    await tester.pumpAndSettle();
    expect(deleted, ['m-1']);
    expect(find.text('buzz near 5k'), findsNothing);
    expect(find.text('Noise'), findsOneWidget);

    // Unhappy path: delete failure keeps row and shows SnackBar error.
    failDelete = true;
    await tester.tap(find.byKey(const ValueKey('delete-mark-m-2')));
    await tester.pumpAndSettle();
    expect(find.text('Noise'), findsOneWidget);
    expect(find.textContaining('Could not delete mark'), findsOneWidget);
  });
}
