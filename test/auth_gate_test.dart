import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/auth_client.dart';
import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:vehicle_mobile/services/auth_store.dart';
import 'package:vehicle_mobile/services/host_store.dart';
import 'package:vehicle_mobile/ui/auth/auth_gate.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

import 'support/memory_secrets.dart';
import 'support/signed_in.dart';

const _url = 'https://vehicle.example.test';

const _session = {
  'token': 'session-token',
  'expires_utc': '2026-12-25T10:00:00Z',
  'user': {'username': 'rider'},
  'vehicles': [
    {'vehicle_id': 'veh-1', 'name': 'CL250'}
  ],
};

Widget _app(AppSettingsStore store, AuthClient client, {bool skip = false}) =>
    MaterialApp(
      theme: buildAppTheme(),
      home: AuthGate(
        store: store,
        client: client,
        allowSkip: skip,
        builder: (_) => const Scaffold(body: Text('APP-CONTENT')),
      ),
    );

AuthClient _client(Future<http.Response> Function(http.Request) handler) =>
    AuthClient(httpClient: MockClient(handler));

Future<void> _fillLogin(WidgetTester tester) async {
  await tester.enterText(find.byKey(const ValueKey('server-url')), _url);
  await tester.enterText(find.byKey(const ValueKey('username')), 'rider');
  await tester.enterText(find.byKey(const ValueKey('password')), 'pw-123456');
}

void main() {
  late MemorySecrets secrets;
  late AppSettingsStore empty;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secrets = MemorySecrets();
    empty = AppSettingsStore(secrets: secrets);
  });

  testWidgets('no token shows the login screen, not the app', (tester) async {
    await tester
        .pumpWidget(_app(empty, _client((_) async => http.Response('', 500))));
    await tester.pumpAndSettle();
    expect(find.text('APP-CONTENT'), findsNothing);
    expect(find.byKey(const ValueKey('username')), findsOneWidget);
    expect(find.byKey(const ValueKey('submit')), findsOneWidget);
  });

  testWidgets('password field is obscured and autocorrect is off',
      (tester) async {
    await tester
        .pumpWidget(_app(empty, _client((_) async => http.Response('', 500))));
    await tester.pumpAndSettle();
    final password =
        tester.widget<TextField>(find.byKey(const ValueKey('password')));
    expect(password.obscureText, isTrue);
    expect(password.autocorrect, isFalse);
    expect(password.enableSuggestions, isFalse);
    final user =
        tester.widget<TextField>(find.byKey(const ValueKey('username')));
    expect(user.autocorrect, isFalse);
  });

  testWidgets('login success stores the token per host and opens the app',
      (tester) async {
    late http.Request seen;
    await tester.pumpWidget(_app(empty, _client((r) async {
      seen = r;
      return http.Response(jsonEncode(_session), 200);
    })));
    await tester.pumpAndSettle();
    await _fillLogin(tester);
    await tester.tap(find.byKey(const ValueKey('submit')));
    await tester.pumpAndSettle();

    expect(seen.url.toString(), '$_url/auth/login');
    expect(find.text('APP-CONTENT'), findsOneWidget);
    final hosts = await empty.hosts.load();
    expect(hosts.single.baseUrl, _url);
    expect(
        secrets.values[HostStore.tokenKey(hosts.single.id)], 'session-token');
    final account = await AuthStore(empty.hosts).readAccount(hosts.single.id);
    expect(account!.username, 'rider');
    expect(account.vehicles.single.vehicleId, 'veh-1');
    // The token is not in shared_preferences.
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      expect('${prefs.get(key)}', isNot(contains('session-token')));
    }
  });

  testWidgets('wrong password shows the generic Turkish message',
      (tester) async {
    await tester.pumpWidget(_app(
        empty,
        _client((_) async =>
            http.Response('{"detail":"invalid username or password"}', 401))));
    await tester.pumpAndSettle();
    await _fillLogin(tester);
    await tester.tap(find.byKey(const ValueKey('submit')));
    await tester.pumpAndSettle();
    expect(find.text('Kullanıcı adı veya parola hatalı.'), findsOneWidget);
    expect(find.text('APP-CONTENT'), findsNothing);
  });

  testWidgets('429 shows the wait time', (tester) async {
    await tester.pumpWidget(_app(
        empty,
        _client((_) async =>
            http.Response('', 429, headers: {'retry-after': '42'}))));
    await tester.pumpAndSettle();
    await _fillLogin(tester);
    await tester.tap(find.byKey(const ValueKey('submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('42 sn'), findsOneWidget);
  });

  testWidgets(
      'register form asks vehicle id and claim code; 409 and 403 messages',
      (tester) async {
    var status = 409;
    late http.Request seen;
    await tester.pumpWidget(_app(empty, _client((r) async {
      seen = r;
      return http.Response('{"detail":"x"}', status);
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vehicle-id')), findsOneWidget);
    expect(find.byKey(const ValueKey('claim-code')), findsOneWidget);
    await _fillLogin(tester);
    await tester.enterText(find.byKey(const ValueKey('vehicle-id')), 'veh-1');
    await tester.enterText(find.byKey(const ValueKey('claim-code')), 'CODE');
    await tester.tap(find.byKey(const ValueKey('submit')));
    await tester.pumpAndSettle();
    expect(seen.url.path, '/auth/register');
    expect(find.text('Bu kullanıcı adı alınmış.'), findsOneWidget);

    status = 403;
    await tester.tap(find.byKey(const ValueKey('submit')));
    await tester.pumpAndSettle();
    expect(find.text('Araç kimliği veya kod geçersiz.'), findsOneWidget);
  });

  testWidgets('a 401 anywhere clears the host session and returns to login',
      (tester) async {
    final store = signedInStore(secrets: secrets);
    await tester
        .pumpWidget(_app(store, _client((_) async => http.Response('', 500))));
    await tester.pumpAndSettle();
    expect(find.text('APP-CONTENT'), findsOneWidget);

    AuthEvents.reportUnauthorized();
    await tester.pumpAndSettle();
    expect(find.text('APP-CONTENT'), findsNothing);
    expect(find.textContaining('Oturum sona erdi'), findsOneWidget);
    expect(secrets.values[HostStore.tokenKey('h1')], isNull);
  });

  testWidgets('the manual device token path stays available', (tester) async {
    await tester
        .pumpWidget(_app(empty, _client((_) async => http.Response('', 500))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('server-url')), _url);
    await tester.tap(find.byKey(const ValueKey('advanced')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('device-token')), 'dev-token');
    await tester.tap(find.byKey(const ValueKey('connect-token')));
    await tester.pumpAndSettle();
    expect(find.text('APP-CONTENT'), findsOneWidget);
    final hosts = await empty.hosts.load();
    expect(secrets.values[HostStore.tokenKey(hosts.single.id)], 'dev-token');
  });

  testWidgets('http to a public host is refused in the form', (tester) async {
    var called = false;
    await tester.pumpWidget(_app(empty, _client((_) async {
      called = true;
      return http.Response('', 200);
    })));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('server-url')), 'http://example.com');
    await tester.enterText(find.byKey(const ValueKey('username')), 'u');
    await tester.enterText(find.byKey(const ValueKey('password')), 'p');
    await tester.tap(find.byKey(const ValueKey('submit')));
    await tester.pumpAndSettle();
    expect(called, isFalse);
    expect(find.textContaining('Güvenli olmayan adres'), findsOneWidget);
  });

  testWidgets('on the phone the login can be skipped and the app stays mounted',
      (tester) async {
    await tester.pumpWidget(
        _app(empty, _client((_) async => http.Response('', 500)), skip: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skip')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('skip')));
    await tester.pumpAndSettle();
    expect(find.text('APP-CONTENT'), findsOneWidget);
    expect(find.byKey(const ValueKey('submit')), findsNothing);
  });

  testWidgets('a known host list offers a picker and prefills the URL',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'hosts.v1': jsonEncode([
        {'id': 'a', 'name': 'Bike', 'base_url': 'http://192.168.1.20:8000'},
        {'id': 'b', 'name': 'Remote', 'base_url': _url},
      ])
    });
    await tester
        .pumpWidget(_app(empty, _client((_) async => http.Response('', 500))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('host-picker')), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('server-url')))
            .controller!
            .text,
        'http://192.168.1.20:8000');
  });
}
