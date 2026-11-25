import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/ui/widgets/readout.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/ride_client.dart';
import 'package:vehicle_mobile/ui/rides/ride_history_screen.dart';
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

String _ridesJson({
  required List<Map<String, Object?>> rows,
  int skipped = 0,
  List<Map<String, Object?>>? columns,
}) =>
    jsonEncode({
      'columns': columns ??
          [
            {'name': 'ride_distance', 'unit': 'km'},
            {'name': 'ride_time', 'unit': 's'},
            {'name': 'ride_stop_count', 'unit': 'count'},
            {'name': 'speed', 'unit': 'km/h'},
            {'name': 'rpm', 'unit': 'rpm'},
            {'name': 'lean', 'unit': 'deg'},
          ],
      'rows': rows,
      'skipped': skipped,
    });

Map<String, Object?> _row(
  String id,
  String createdUtc, {
  double? speed,
  double? rpm,
  double? lean,
  double distance = 20,
  Map<String, String> flags = const {},
}) =>
    {
      'session_id': id,
      'created_utc': createdUtc,
      'values': {
        'ride_distance': distance,
        'ride_time': 1215,
        'ride_stop_count': 2,
        'speed': speed,
        'rpm': rpm,
        'lean': lean,
      },
      'flags': flags,
    };

http.Response _ok(String body) =>
    http.Response(body, 200, headers: {'content-type': 'application/json'});

Future<void> _drain(WidgetTester tester) async {
  for (var index = 0; index < 6; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// A [Readout] with this value and unit (the value and unit are separate texts).
Finder _readout(String value, String unit) => find.byWidgetPredicate(
    (w) => w is Readout && w.value == value && w.unit == unit);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows a server-not-configured message without making a request',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var requests = 0;
    final client = RideClient(httpClient: MockClient((request) async {
      requests++;
      return _ok(_ridesJson(rows: const []));
    }));

    await tester.pumpWidget(_host(RideHistoryScreen(
      settingsStore: _store(null, null),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('No vehicle-server configured'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('shows loading, then a failure with an inline retry that reloads',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final first = Completer<http.Response>();
    var requests = 0;
    final client = RideClient(httpClient: MockClient((request) {
      requests++;
      if (requests == 1) return first.future;
      return Future.value(_ok(_ridesJson(rows: [
        _row('20260116-090000-bbbb', '2026-01-16T09:00:00Z',
            speed: 82.5, rpm: 7000, lean: 12),
      ])));
    }));

    await tester.pumpWidget(_host(RideHistoryScreen(
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await _drain(tester);
    expect(find.text('Loading rides...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    first.complete(http.Response('', 500));
    await tester.pumpAndSettle();
    expect(find.text('HTTP 500'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Logbook'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(find.text('2026-01-16 09:00 UTC'), findsOneWidget);
    expect(find.text('HTTP 500'), findsNothing);
  });

  testWidgets('shows the empty range and the skipped-session count',
      (tester) async {
    final client = RideClient(
        httpClient: MockClient(
            (request) async => _ok(_ridesJson(rows: const [], skipped: 2))));

    await tester.pumpWidget(_host(RideHistoryScreen(
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(find.text('No rides in this range.'), findsOneWidget);
    expect(find.textContaining('2 sessions without a stored summary skipped'),
        findsOneWidget);
  });

  testWidgets(
      'orders rows newest first and shows the chosen values with units and flags',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(
        httpClient: MockClient((request) async => _ok(_ridesJson(rows: [
              _row('20260115-090000-aaaa', '2026-01-15T09:00:00Z',
                  speed: 40, rpm: 3000, flags: {'lean': 'missing'}),
              _row('20260116-090000-bbbb', '2026-01-16T09:00:00Z',
                  speed: 82.5, rpm: 7000, lean: 12),
            ]))));

    await tester.pumpWidget(_host(RideHistoryScreen(
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    final newer = tester.getTopLeft(find.text('2026-01-16 09:00 UTC')).dy;
    final older = tester.getTopLeft(find.text('2026-01-15 09:00 UTC')).dy;
    expect(newer, lessThan(older));
    // Rider quantities first, with human labels; no engineering signals.
    expect(find.text('DISTANCE'), findsNWidgets(2));
    expect(find.text('RIDE TIME'), findsNWidgets(2));
    expect(find.text('STOPS'), findsNWidgets(2));
    expect(find.text('20 min 15 s'), findsNWidgets(2));
    expect(_readout('82.500', 'km/h'), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('2026-01-16 09:00 UTC'), findsOneWidget);
    expect(find.textContaining('20260116-090000-bbbb'), findsNothing);
  });

  testWidgets(
      'the compare sheet keeps engineering signals under All signals and shows chosen ones with units and flags',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(
        httpClient: MockClient((request) async => _ok(_ridesJson(rows: [
              _row('20260115-090000-aaaa', '2026-01-15T09:00:00Z',
                  speed: 40, rpm: 3000, flags: {'lean': 'missing'}),
              _row('20260116-090000-bbbb', '2026-01-16T09:00:00Z',
                  speed: 82.5, rpm: 7000, lean: 12),
            ]))));

    await tester.pumpWidget(_host(RideHistoryScreen(
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    // No chip wall above the list.
    expect(find.byType(FilterChip), findsNothing);

    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    expect(find.text('Compare rides'), findsOneWidget);
    expect(find.text('All signals'), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);

    await tester.tap(find.text('All signals'));
    await tester.pumpAndSettle();
    expect(find.byType(FilterChip), findsNWidgets(3));

    await tester.tap(find.widgetWithText(FilterChip, 'Rpm'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Lean'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(_readout('12.000', 'deg'), findsOneWidget);
    expect(_readout('\u2013', 'deg'), findsOneWidget);
    expect(find.text('missing'), findsOneWidget);
    expect(_readout('7000.0', 'rpm'), findsOneWidget);
  });

  testWidgets('lays out on a 360 px phone at 2x text scale', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(
        httpClient: MockClient((request) async => _ok(_ridesJson(rows: [
              _row('20260115-090000-aaaa', '2026-01-15T09:00:00Z',
                  speed: 40, rpm: 3000, flags: {'lean': 'missing'}),
              _row('20260116-090000-bbbb', '2026-01-16T09:00:00Z',
                  speed: 82.5, rpm: 7000, lean: 12),
            ]))));

    await tester.pumpWidget(_host(
      RideHistoryScreen(
        settingsStore: _store('https://vehicle-server.example.com', 't'),
        client: client,
      ),
      textScale: 2,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Logbook'), findsOneWidget);
  });

  testWidgets('a chosen date range reaches the request and Clear removes it',
      (tester) async {
    final requested = <Uri>[];
    final client = RideClient(httpClient: MockClient((request) async {
      requested.add(request.url);
      return _ok(_ridesJson(rows: const []));
    }));
    final ranges = [
      DateTimeRange(
          start: DateTime.utc(2026, 1, 1), end: DateTime.utc(2026, 1, 5)),
    ];

    await tester.pumpWidget(_host(RideHistoryScreen(
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
      dateRangePicker: (context, initial) async => ranges.removeAt(0),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Date range'));
    await tester.pumpAndSettle();

    expect(requested.last.queryParameters['from'], '2026-01-01');
    expect(requested.last.queryParameters['to'], '2026-01-05');
    expect(find.text('2026-01-01 – 2026-01-05 (UTC days)'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(requested.last.queryParameters.containsKey('from'), isFalse);
    expect(requested.last.queryParameters.containsKey('to'), isFalse);
    expect(find.text('All rides'), findsOneWidget);
  });

  testWidgets('ignores a response that arrives after the range changed',
      (tester) async {
    final completers = <Completer<http.Response>>[];
    final client = RideClient(httpClient: MockClient((request) {
      final completer = Completer<http.Response>();
      completers.add(completer);
      return completer.future;
    }));
    final ranges = [
      DateTimeRange(
          start: DateTime.utc(2026, 1, 1), end: DateTime.utc(2026, 1, 5)),
      DateTimeRange(
          start: DateTime.utc(2026, 1, 1), end: DateTime.utc(2026, 1, 6)),
    ];

    await tester.pumpWidget(_host(RideHistoryScreen(
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
      dateRangePicker: (context, initial) async => ranges.removeAt(0),
    )));
    await _drain(tester);
    expect(completers, hasLength(1));
    completers[0].complete(_ok(_ridesJson(rows: [
      _row('20260110-090000-base', '2026-01-10T09:00:00Z',
          speed: 10, rpm: 1000),
    ])));
    await _drain(tester);
    expect(find.text('2026-01-10 09:00 UTC'), findsOneWidget);

    await tester.tap(find.text('Date range'));
    await _drain(tester);
    expect(completers, hasLength(2));

    await tester.tap(find.text('Change range'));
    await _drain(tester);
    expect(completers, hasLength(3));

    completers[2].complete(_ok(_ridesJson(rows: [
      _row('20260116-090000-new', '2026-01-16T09:00:00Z', speed: 20, rpm: 2000),
    ])));
    await _drain(tester);
    expect(find.text('2026-01-16 09:00 UTC'), findsOneWidget);

    completers[1].complete(_ok(_ridesJson(rows: [
      _row('20260115-090000-old', '2026-01-15T09:00:00Z', speed: 30, rpm: 3000),
    ])));
    await _drain(tester);
    expect(find.text('2026-01-16 09:00 UTC'), findsOneWidget);
    expect(find.text('2026-01-15 09:00 UTC'), findsNothing);
  });

  testWidgets('tapping a row opens its ride summary', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/summary')) {
        return _ok(jsonEncode({
          'session_id': '20260116-090000-bbbb',
          'ride_definition': 'ride.yaml',
          'defs_version': '1.2.3',
          'signals': [
            {
              'name': 'speed',
              'status': 'computed',
              'unit': 'km/h',
              'range': [0, 200],
              'kind': 'scalar',
              'value': 82.5,
              'flag': null,
            }
          ],
        }));
      }
      return _ok(_ridesJson(rows: [
        _row('20260116-090000-bbbb', '2026-01-16T09:00:00Z',
            speed: 82.5, rpm: 7000, lean: 12),
      ]));
    }));

    await tester.pumpWidget(_host(RideHistoryScreen(
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2026-01-16 09:00 UTC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ride summary'), findsOneWidget);
  });

  testWidgets('shows the cleartext warning for a remote http server',
      (tester) async {
    final client = RideClient(
        httpClient:
            MockClient((request) async => _ok(_ridesJson(rows: const []))));

    await tester.pumpWidget(_host(RideHistoryScreen(
      settingsStore: _store('http://192.168.1.50:8080', 't'),
      client: client,
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('unencrypted'), findsOneWidget);
  });

  testWidgets('does not call setState after the screen is disposed',
      (tester) async {
    final completer = Completer<http.Response>();
    final client =
        RideClient(httpClient: MockClient((request) => completer.future));

    await tester.pumpWidget(_host(RideHistoryScreen(
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
    )));
    await _drain(tester);

    await tester.pumpWidget(const SizedBox());
    completer.complete(_ok(_ridesJson(rows: const [])));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Turkish locale translates the screen and the rows keep readouts',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(httpClient: MockClient((request) async => _ok(
        _ridesJson(rows: [
          _row('20260116-090000-bbbb', '2026-01-16T09:00:00Z',
              speed: 82.5, rpm: 7000, lean: 12),
        ]))));
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      locale: const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RideHistoryScreen(
        settingsStore: _store('https://vehicle-server.example.com', 't'),
        client: client,
      ),
    ));
    await _drain(tester);

    expect(find.text('Günlük'), findsOneWidget);
    expect(find.text('1 sürüş'), findsOneWidget);
    expect(find.text('Tarih aralığı'), findsOneWidget);
    expect(find.text('Tüm sürüşler'), findsOneWidget);
    expect(find.text('MESAFE'), findsOneWidget);
    expect(find.text('Karşılaştır'), findsOneWidget);
  });

  testWidgets('onOpenRide hands the session to the wide detail pane',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = RideClient(httpClient: MockClient((request) async => _ok(
        _ridesJson(rows: [
          _row('20260116-090000-bbbb', '2026-01-16T09:00:00Z',
              speed: 82.5, rpm: 7000, lean: 12),
        ]))));
    final opened = <String>[];
    await tester.pumpWidget(_host(RideHistoryScreen(
      settingsStore: _store('https://vehicle-server.example.com', 't'),
      client: client,
      onOpenRide: opened.add,
    )));
    await _drain(tester);

    await tester.tap(find.text('2026-01-16 09:00 UTC'));
    await tester.pump();
    expect(opened, ['20260116-090000-bbbb']);
    // No route was pushed.
    expect(find.text('Ride summary'), findsNothing);
  });
}
