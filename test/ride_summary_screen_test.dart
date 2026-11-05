import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/ride_client.dart';
import 'package:vehicle_mobile/ui/rides/bringup_screen.dart';
import 'package:vehicle_mobile/ui/rides/health_windows_section.dart';
import 'package:vehicle_mobile/ui/rides/ride_summary_screen.dart';
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

Widget _host(Widget child, {double textScale = 1.0}) => MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: child,
    );

AppSettingsStore _store(String? baseUrl, String? token) {
  SharedPreferences.setMockInitialValues({
    if (baseUrl != null) 'settings.server_base_url': baseUrl,
  });
  return AppSettingsStore(secrets: _MemorySecrets(token));
}

Map<String, Object?> _summaryFixture({bool mismatch = true}) => {
      'session_id': '20260116-090000-bbbb',
      'ride_definition': 'cl250_ride.yaml',
      'defs_version': '1.2.3',
      'signals': [
        {
          'name': 'ride_distance_gps',
          'status': 'computed',
          'unit': 'km',
          'range': [0, 100],
          'kind': 'scalar',
          'value': 12.345,
          'flag': 'gps_fix_type_ignored',
        },
        {
          'name': 'ride_time',
          'status': 'computed',
          'unit': 's',
          'range': [0, 7200],
          'kind': 'scalar',
          'value': 900,
          'flag': null,
        },
        {
          'name': 'ride_coolant_peak',
          'status': 'computed',
          'unit': 'degC',
          'range': [0, 120],
          'kind': 'scalar',
          'value': null,
          'flag': 'missing',
        },
        {
          'name': 'ride_coolant_time_at_temp',
          'status': 'computed',
          'unit': 's',
          'range': [0, 600],
          'kind': 'binned',
          'axes': [
            {
              'input': 'did.COOLANT_TEMP',
              'unit': 'degC',
              'edges': [
                [0, 40],
                [40, 80],
                [80, 120],
              ],
            }
          ],
          'cells': [
            {'index': 0, 'axes': [0], 'value': 120.0, 'flag': null},
            {'index': 1, 'axes': [1], 'value': 300.0, 'flag': null},
            {'index': 2, 'axes': [2], 'value': null, 'flag': 'missing'},
          ],
          'total_s': 420.0,
          'outside_s': 6.0,
        },
        {
          'name': 'operating_point_time',
          'status': 'computed',
          'unit': 's',
          'range': [0, 100],
          'kind': 'binned',
          'axes': [
            {
              'input': 'ENGINE_SPEED',
              'unit': 'rpm',
              'edges': [
                [0, 3000],
                [3000, 6000],
              ],
            },
            {
              'input': 'ENGINE_LOAD',
              'unit': '%',
              'edges': [
                [0, 50],
                [50, 100],
              ],
            },
          ],
          'cells': [
            {'index': 0, 'axes': [0, 0], 'value': 10.0, 'flag': null},
            {'index': 1, 'axes': [1, 0], 'value': 30.0, 'flag': null},
            {'index': 2, 'axes': [0, 1], 'value': 20.0, 'flag': 'high'},
            {'index': 3, 'axes': [1, 1], 'value': 40.0, 'flag': null},
          ],
          'total_s': 60.0,
          'outside_s': 0.0,
          if (mismatch) 'defs_mismatch': true,
        },
        {
          'name': 'ride_fuel_used',
          'status': 'missing_inputs',
          'reason': 'no fuel input',
          'pending_inputs': ['did.FUEL_LEVEL'],
          'missing': <String>[],
        },
        {
          'name': 'ride_gear_time',
          'status': 'error',
          'reason': 'decode failed',
          'pending_inputs': <String>[],
          'missing': ['did.GEAR'],
          'message': 'stored value is unusable',
        },
      ],
    };

Map<String, Object?> _perGearSummaryFixture() => {
      'session_id': '20260116-090000-bbbb',
      'ride_definition': 'cl250_ride.yaml',
      'defs_version': '1.2.3',
      'signals': [
        {
          'name': 'ride_final_drive_ratio',
          'status': 'computed',
          'unit': 'ratio',
          'range': [2.0, 3.5],
          'kind': 'per_gear',
          'gears': [
            {'gear': 4, 'value': null, 'flag': 'no_steady_samples'},
            {'gear': 1, 'value': 2.64, 'flag': null},
          ],
        },
      ],
    };

Map<String, Object?> _wideSummaryFixture() => {
      'session_id': '20260116-090000-bbbb',
      'ride_definition': 'cl250_ride.yaml',
      'defs_version': '1.2.3',
      'signals': [
        {
          'name': 'operating_point_time',
          'status': 'computed',
          'unit': 's',
          'range': [0, 100],
          'kind': 'binned',
          'axes': [
            {
              'input': 'ENGINE_SPEED',
              'unit': 'rpm',
              'edges': [
                [0, 1000],
                [1000, 2000],
                [2000, 3000],
                [3000, 4000],
                [4000, 5000],
                [5000, 6000],
                [6000, 7000],
                [7000, 8000],
              ],
            },
            {
              'input': 'ENGINE_LOAD',
              'unit': '%',
              'edges': [
                [0, 50],
                [50, 100],
              ],
            },
          ],
          'cells': [
            for (var row = 0; row < 2; row++)
              for (var column = 0; column < 8; column++)
                {
                  'index': row * 8 + column,
                  'axes': [column, row],
                  'value': (row + 1) * 10.0 + column,
                  'flag': null,
                }
          ],
          'total_s': 60.0,
          'outside_s': 0.0,
        },
      ],
    };

Map<String, Object?> _healthReportFixture() => {
      'derived_summary': {
        'health_windows': {
          'rule': "provisional: Claude's reading of D-079 (vehicle-server README)",
          't0_device_ms': 1000,
          'windows': {
            'W3_WARM_IDLE': {
              'qualifying_count': 1,
              'instances': [
                {
                  'start_ms': 3000,
                  'end_ms': 30000,
                  'duration_ms': 27000,
                  'close_reason': 'condition',
                  'qualifies': true,
                  'first_qualifying': true,
                },
                {
                  'start_ms': 40000,
                  'end_ms': 41000,
                  'duration_ms': 1000,
                  'close_reason': 'session_end',
                  'qualifies': false,
                  'first_qualifying': false,
                },
              ],
            },
            'W1_KEY_ON': {'qualifying_count': 0, 'instances': <Object?>[]},
          },
        },
      },
    };

Map<String, Object?> _summaryWithWindowSignal() {
  final summary = _summaryFixture();
  (summary['signals'] as List).insert(0, {
    'name': 'window_warm_idle_count',
    'status': 'computed',
    'unit': 'count',
    'range': [0, 10],
    'kind': 'scalar',
    'value': 1,
    'flag': null,
    'window': 'W3_WARM_IDLE',
  });
  return summary;
}

Map<String, Object?> _bringupFixture() => {
      'session_id': '20260116-090000-bbbb',
      'gate': 'V0',
      'verdict': 'pass',
      'checks': [
        {
          'id': 'ecu_present',
          'status': 'pass',
          'measured': {'present_rows': 12, 'absent_rows': 0},
          'expected': 'ecuPresent set on every CAN health row',
          'source': 'hardware-integration.md §6 V0',
          'note': 'Synthetic test check.',
        },
      ],
      'needs_you': <String>[],
      'warnings': <String>[],
    };

http.Response _ok(Map<String, Object?> body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

Future<void> _drain(WidgetTester tester) async {
  for (var index = 0; index < 6; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows a server-not-configured message without making a request', (tester) async {
    var requests = 0;
    final client = RideClient(httpClient: MockClient((request) async {
      requests++;
      return _ok(_summaryFixture());
    }));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store(null, null),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('No vehicle-server configured'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('shows loading, then the server message when the summary is missing', (tester) async {
    final completer = Completer<http.Response>();
    final client = RideClient(httpClient: MockClient((request) => completer.future));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await _drain(tester);

    expect(find.text('Loading ride summary...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(http.Response(jsonEncode({'message': 'session has no ride summary'}), 404));
    await tester.pumpAndSettle();

    expect(find.text('session has no ride summary'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows a failure and retries the request', (tester) async {
    var requests = 0;
    final client = RideClient(httpClient: MockClient((request) async {
      requests++;
      if (requests == 1) return http.Response('', 500);
      return _ok(_summaryFixture());
    }));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(find.text('HTTP 500'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(requests, 3);
    expect(find.text('ride cl250_ride.yaml'), findsOneWidget);
    expect(find.text('HTTP 500'), findsNothing);
  });

  testWidgets('renders the header, scalar values, one-axis chart, heat grid, mismatch and unavailable list', (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(httpClient: MockClient((request) async => _ok(_summaryFixture())));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(find.text('20260116-090000-bbbb'), findsOneWidget);
    expect(find.text('ride cl250_ride.yaml'), findsOneWidget);
    expect(find.text('defs 1.2.3'), findsOneWidget);
    expect(find.text('12.35 km'), findsOneWidget);
    expect(find.text('900.0 s'), findsOneWidget);
    expect(find.text('– degC'), findsOneWidget);
    expect(find.text('gps_fix_type_ignored'), findsOneWidget);

    expect(find.text('did.COOLANT_TEMP [degC]'), findsOneWidget);
    expect(find.text('0.00–40.00'), findsOneWidget);
    expect(find.text('total 7 min 00 s · outside 6 s'), findsOneWidget);

    // Rows = axes[0], columns = axes[1], like the analyzer; cell axes [0, 1]
    // is row 0, column 1.
    expect(find.text('rows: ENGINE_SPEED [rpm]'), findsOneWidget);
    expect(find.text('columns: ENGINE_LOAD [%]'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('heat-cell-operating_point_time-0-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('20.00 s · high'), findsOneWidget);

    expect(find.textContaining('Decoded with other defs bin edges'), findsOneWidget);
    expect(find.textContaining('operating_point_time'), findsWidgets);

    expect(find.text('Not available (2)'), findsOneWidget);
    expect(find.text('ride_fuel_used'), findsNothing);
    await tester.tap(find.text('Not available (2)'));
    await tester.pumpAndSettle();
    expect(find.text('ride_fuel_used'), findsOneWidget);
    expect(find.text('missing_inputs'), findsOneWidget);
    expect(find.textContaining('no fuel input'), findsOneWidget);
    expect(find.text('ride_gear_time'), findsOneWidget);
    expect(find.textContaining('stored value is unusable'), findsOneWidget);
  });

  testWidgets('the heat grid scrolls horizontally on a wide 360 px screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(httpClient: MockClient((request) async => _ok(_wideSummaryFixture())));

    await tester.pumpWidget(_host(
      RideSummaryScreen(
        sessionId: '20260116-090000-bbbb',
        settingsStore: _store('https://vehicle-server.example.com', 't'),
        client: client,
      ),
      textScale: 2,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final horizontal = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((view) => view.scrollDirection == Axis.horizontal);
    expect(horizontal, isNotEmpty);
  });

  testWidgets('renders per-gear rows at a 360x690 phone size without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(httpClient: MockClient((request) async => _ok(_perGearSummaryFixture())));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(find.text('PER-GEAR SIGNALS'), findsOneWidget);
    expect(find.text('ride_final_drive_ratio'), findsOneWidget);
    expect(find.text('Gear 1'), findsOneWidget);
    expect(find.text('2.6400 ratio'), findsOneWidget);
    expect(find.text('Gear 4'), findsOneWidget);
    expect(find.text('– ratio'), findsOneWidget);
    expect(find.text('no_steady_samples'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the cleartext warning for a remote http server', (tester) async {
    final client = RideClient(httpClient: MockClient((request) async => _ok(_summaryFixture())));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store('http://192.168.1.50:8080', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('unencrypted'), findsOneWidget);
  });

  testWidgets('does not call setState after the screen is disposed', (tester) async {
    final completer = Completer<http.Response>();
    final client = RideClient(httpClient: MockClient((request) => completer.future));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await _drain(tester);

    await tester.pumpWidget(const SizedBox());
    completer.complete(_ok(_summaryFixture()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the report health windows with one request per route', (tester) async {
    tester.view.physicalSize = const Size(360, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final paths = <String>[];
    final client = RideClient(httpClient: MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/report')) return _ok(_healthReportFixture());
      return _ok(_summaryWithWindowSignal());
    }));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(paths, [
      '/sessions/20260116-090000-bbbb/summary',
      '/sessions/20260116-090000-bbbb/report',
    ]);
    expect(find.text('HEALTH WINDOWS'), findsOneWidget);
    expect(find.textContaining('provisional:'), findsOneWidget);
    expect(find.text('W3_WARM_IDLE'), findsOneWidget);
    expect(find.text('2 instances, 1 qualifying'), findsOneWidget);
    expect(find.text('27 s'), findsOneWidget);
    expect(find.text('condition'), findsOneWidget);
    expect(find.text('yes'), findsOneWidget);
    expect(find.text('no'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HealthWindowsSection),
        matching: find.text('window_warm_idle_count'),
      ),
      findsOneWidget,
    );

    final timeline = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('health-window-timeline-W3_WARM_IDLE')),
    );
    final painter = timeline.painter! as WindowTimelinePainter;
    expect(painter.instances, hasLength(2));
    expect(painter.firstQualifyingIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the missing-report message without hiding the summary', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/report')) {
        return _ok({'derived_summary': <String, Object?>{}});
      }
      return _ok(_summaryFixture());
    }));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(find.text('ride cl250_ride.yaml'), findsOneWidget);
    expect(find.text(HealthWindowsSection.missingReportMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a malformed-report reason without hiding the summary', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/report')) {
        return _ok({
          'derived_summary': {
            'health_windows': {
              'rule': 'provisional',
              't0_device_ms': 0,
              'windows': {
                'W3_WARM_IDLE': {
                  'qualifying_count': 0,
                  'instances': [
                    {
                      'start_ms': 10,
                      'end_ms': 5,
                      'duration_ms': -5,
                      'close_reason': 'condition',
                      'qualifies': false,
                      'first_qualifying': false,
                    },
                  ],
                },
              },
            },
          },
        });
      }
      return _ok(_summaryFixture());
    }));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(find.text('ride cl250_ride.yaml'), findsOneWidget);
    expect(find.textContaining('malformed:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed report request never hides the summary', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/report')) return http.Response('', 500);
      return _ok(_summaryFixture());
    }));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(find.text('ride cl250_ride.yaml'), findsOneWidget);
    expect(find.text('HTTP 500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app-bar action opens the bring-up check for this session', (tester) async {
    final client = RideClient(httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/bringup')) return _ok(_bringupFixture());
      return _ok(_summaryFixture());
    }));

    await tester.pumpWidget(_host(RideSummaryScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bring-up check'));
    await tester.pumpAndSettle();

    expect(find.byType(BringupScreen), findsOneWidget);
    expect(
      find.descendant(of: find.byType(BringupScreen), matching: find.text('20260116-090000-bbbb')),
      findsOneWidget,
    );
  });
}
