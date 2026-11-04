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

class _ThrowingSecrets implements SecretStore {
  @override
  Future<String?> read(String key) async => throw Exception('secret-boom');

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

Widget _host(Widget child, {double textScale = 1.0}) => MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
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

Map<String, Object?> _check({
  String id = 'ecu_present',
  String status = 'pass',
  Object? measured = const {'present_rows': 12, 'absent_rows': 0},
  String expected = 'ecuPresent set on every CAN health row',
  String source = 'hardware-integration.md §6 V0',
  String note = 'absent_rows = rows with the ecuPresent flag clear.',
}) =>
    {
      'id': id,
      'status': status,
      'measured': measured,
      'expected': expected,
      'source': source,
      'note': note,
    };

Map<String, Object?> _body({
  String gate = 'V0',
  String verdict = 'pass',
  List<Map<String, Object?>>? checks,
  List<String> needsYou = const [],
  List<String> warnings = const [],
}) =>
    {
      'session_id': '20260116-090000-bbbb',
      'gate': gate,
      'verdict': verdict,
      'checks': checks ?? [_check()],
      'needs_you': needsYou,
      'warnings': warnings,
    };

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

Future<void> _pumpScreen(
  WidgetTester tester, {
  required RideClient client,
  required AppSettingsStore store,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(360, 690);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_host(
    BringupScreen(
      sessionId: '20260116-090000-bbbb',
      settingsStore: store,
      client: client,
    ),
    textScale: textScale,
  ));
  await tester.pumpAndSettle();
}

Finder verdict() => find.byKey(const ValueKey('bringup-verdict'));
Finder checkCard(String id) => find.byKey(ValueKey('bringup-check-$id'));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders a pass at phone size without overflow', (tester) async {
    final client = RideClient(
      httpClient: MockClient((request) async => _ok(_body(checks: [
            _check(id: 'ecu_present'),
            _check(id: 'dids_valid', measured: {
              'ENGINE_SPEED': {'valid_count': 12}
            }),
          ]))),
    );

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', 't'),
    );

    expect(find.text('Bring-up check'), findsOneWidget);
    expect(find.text('20260116-090000-bbbb'), findsOneWidget);
    expect(find.descendant(of: verdict(), matching: find.text('pass')),
        findsOneWidget);
    expect(checkCard('ecu_present'), findsOneWidget);
    await tester.scrollUntilVisible(checkCard('dids_valid'), 200);
    await tester.pumpAndSettle();
    expect(checkCard('dids_valid'), findsOneWidget);
    expect(find.text('ENGINE_SPEED: valid_count: 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a fail and the failing check details', (tester) async {
    final client = RideClient(
      httpClient: MockClient((request) async => _ok(_body(
            verdict: 'fail',
            checks: [
              _check(id: 'ecu_present'),
              _check(
                id: 'no_bus_off',
                status: 'fail',
                measured: {
                  'max_bus_off_count': 1,
                  'bus_states_seen': ['busOff']
                },
                expected: 'bus-off count 0 and no busOff state',
                note: 'busOffCount is cumulative since the node booted.',
              ),
            ],
          ))),
    );

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', 't'),
    );

    expect(find.descendant(of: verdict(), matching: find.text('fail')),
        findsOneWidget);
    await tester.scrollUntilVisible(checkCard('no_bus_off'), 200);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: checkCard('no_bus_off'), matching: find.text('fail')),
      findsOneWidget,
    );
    expect(find.text('max_bus_off_count: 1\nbus_states_seen: busOff'),
        findsOneWidget);
    expect(find.text('bus-off count 0 and no busOff state'), findsOneWidget);
    expect(find.text('busOffCount is cumulative since the node booted.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders incomplete with two manual checks pending',
      (tester) async {
    final client = RideClient(
      httpClient: MockClient((request) async => _ok(_body(
            verdict: 'incomplete',
            checks: [
              _check(id: 'at_rest', status: 'manual', measured: null),
              _check(
                  id: 'rpm_throttle_blip',
                  status: 'manual',
                  measured: {'max': 3200}),
            ],
            needsYou: ['at_rest', 'rpm_throttle_blip'],
          ))),
    );

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', 't'),
    );

    expect(find.descendant(of: verdict(), matching: find.text('incomplete')),
        findsOneWidget);
    expect(find.text('2 manual checks pending: at_rest, rpm_throttle_blip'),
        findsOneWidget);
    expect(find.textContaining('you judge it at the bike'), findsOneWidget);
    expect(find.textContaining('V1 throttle blip'), findsNothing);
    expect(
        find.textContaining('the session has no data for it'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows warnings and the warning check', (tester) async {
    final client = RideClient(
      httpClient: MockClient((request) async => _ok(_body(
            checks: [
              _check(
                  id: 'step_gap',
                  status: 'warn',
                  measured: {'step_gap_over_count': 2})
            ],
            warnings: ['step_gap'],
          ))),
    );

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', 't'),
    );

    expect(find.text('1 warning: step_gap'), findsOneWidget);
    expect(
      find.descendant(of: checkCard('step_gap'), matching: find.text('warn')),
      findsOneWidget,
    );
    expect(find.text('step_gap_over_count: 2'), findsOneWidget);
  });

  testWidgets('shows an unknown status verbatim and not as pass',
      (tester) async {
    final client = RideClient(
      httpClient: MockClient((request) async => _ok(_body(
            checks: [_check(id: 'future_check', status: 'future_status')],
          ))),
    );

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', 't'),
    );

    expect(
      find.descendant(
          of: checkCard('future_check'), matching: find.text('future_status')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: checkCard('future_check'), matching: find.text('pass')),
      findsNothing,
    );
  });

  testWidgets('changing the gate sends a new request with that gate',
      (tester) async {
    final gates = <String>[];
    final client = RideClient(httpClient: MockClient((request) async {
      final gate = request.url.queryParameters['gate']!;
      gates.add(gate);
      return _ok(_body(gate: gate, verdict: gate == 'B0' ? 'fail' : 'pass'));
    }));

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', 't'),
    );
    expect(gates, ['V0']);

    await tester.tap(find.text('B0'));
    await tester.pumpAndSettle();

    expect(gates, ['V0', 'B0']);
    expect(find.descendant(of: verdict(), matching: find.text('fail')),
        findsOneWidget);
  });

  testWidgets('shows the old-server message for a 404 Not Found',
      (tester) async {
    final client = RideClient(
      httpClient: MockClient((request) async =>
          http.Response(jsonEncode({'detail': 'Not Found'}), 404)),
    );

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', 't'),
    );

    expect(
      find.text(
        'this server has no bring-up check (needs vehicle-server with the bring-up route, server#50)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the unknown-session message for another 404',
      (tester) async {
    final client = RideClient(
      httpClient: MockClient((request) async => http.Response(
          jsonEncode({'detail': 'unknown session: 20260116-090000-bbbb'}),
          404)),
    );

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', 't'),
    );

    expect(
        find.text(
            'the server does not have this session (upload it first): unknown session: 20260116-090000-bbbb'),
        findsOneWidget);
  });

  testWidgets('lists several warning ids in server order', (tester) async {
    final client = RideClient(
      httpClient: MockClient((request) async => _ok(_body(
            checks: [_check(id: 'b_check'), _check(id: 'a_check')],
            warnings: ['b_check', 'a_check'],
          ))),
    );

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', 't'),
    );

    expect(find.text('2 warnings: b_check, a_check'), findsOneWidget);
  });

  testWidgets('pull-to-refresh keeps the old content until the new answer',
      (tester) async {
    var calls = 0;
    final second = Completer<http.Response>();
    final client = RideClient(httpClient: MockClient((request) {
      calls++;
      if (calls == 1) return Future.value(_ok(_body(verdict: 'pass')));
      return second.future;
    }));

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', 't'),
    );
    expect(find.descendant(of: verdict(), matching: find.text('pass')),
        findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(calls, 2);
    expect(find.text('Loading bring-up check...'), findsNothing);
    expect(find.descendant(of: verdict(), matching: find.text('pass')),
        findsOneWidget);

    second.complete(_ok(_body(verdict: 'fail')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: verdict(), matching: find.text('fail')),
        findsOneWidget);
    expect(find.descendant(of: verdict(), matching: find.text('pass')),
        findsNothing);
  });

  testWidgets('a gate change clears the old result while loading',
      (tester) async {
    final b0 = Completer<http.Response>();
    final client = RideClient(httpClient: MockClient((request) {
      if (request.url.queryParameters['gate'] == 'B0') return b0.future;
      return Future.value(_ok(_body(verdict: 'pass')));
    }));

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', 't'),
    );
    expect(find.descendant(of: verdict(), matching: find.text('pass')),
        findsOneWidget);

    await tester.tap(find.text('B0'));
    await tester.pump();

    expect(verdict(), findsNothing);
    expect(find.text('Loading bring-up check...'), findsOneWidget);

    b0.complete(_ok(_body(gate: 'B0', verdict: 'fail')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: verdict(), matching: find.text('fail')),
        findsOneWidget);
  });

  testWidgets('a settings read failure shows no exception text',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.server_base_url': 'https://vehicle-server.example.com',
    });
    final store = AppSettingsStore(secrets: _ThrowingSecrets());
    final client =
        RideClient(httpClient: MockClient((request) async => _ok(_body())));

    await _pumpScreen(tester, client: client, store: store);

    expect(find.text('Could not read the server settings.'), findsOneWidget);
    expect(find.textContaining('secret-boom'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('no settings means no request and a link to Settings',
      (tester) async {
    var requests = 0;
    final client = RideClient(httpClient: MockClient((request) async {
      requests++;
      return _ok(_body());
    }));

    await _pumpScreen(tester, client: client, store: _store(null, null));

    expect(requests, 0);
    expect(find.textContaining('No vehicle-server configured'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
  });

  testWidgets('a URL without a token also means no request', (tester) async {
    var requests = 0;
    final client = RideClient(httpClient: MockClient((request) async {
      requests++;
      return _ok(_body());
    }));

    await _pumpScreen(
      tester,
      client: client,
      store: _store('https://vehicle-server.example.com', null),
    );

    expect(requests, 0);
    expect(find.textContaining('No vehicle-server configured'), findsOneWidget);
  });
}
