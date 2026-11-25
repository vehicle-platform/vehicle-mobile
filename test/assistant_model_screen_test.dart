import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/models/account.dart';
import 'package:vehicle_mobile/services/assistant_provider_client.dart';
import 'package:vehicle_mobile/services/auth_store.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/ui/settings/assistant_model_screen.dart';
import 'package:vehicle_mobile/ui/settings_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

import 'support/signed_in.dart';

const _base = 'https://vehicle.example.test';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Map<String, Object?> _provider(String id, String label,
        {bool cloud = true,
        bool available = true,
        String? reason,
        String? model}) =>
    {
      'id': id,
      'label': label,
      'kind': cloud ? 'anthropic' : 'local',
      'cloud': cloud,
      'base_url': id == 'custom' ? '' : null,
      'default_model': model,
      'has_models_endpoint': cloud,
      'data_note': 'Not: $label',
      'available': available,
      'unavailable_reason': reason,
    };

Map<String, Object?> _choice(
        {String provider = 'local',
        String? model,
        bool hasKey = false,
        String? hint,
        bool consent = false,
        bool position = false}) =>
    {
      'provider': provider,
      'model': model,
      'base_url': null,
      'has_key': hasKey,
      'key_hint': hint,
      'consent_cloud': consent,
      'allow_position': position,
      'updated_utc': null,
    };

/// A tiny in-memory vehicle-server for the `/assistant/*` routes.
class _Server {
  _Server({Map<String, Object?>? choice}) : choice = choice ?? _choice();

  Map<String, Object?> choice;
  int putStatus = 200;
  Object putBody = const {'detail': 'x'};
  int modelsStatus = 200;
  Map<String, Object?> testBody = {
    'ok': true,
    'latency_ms': 321,
    'detail': 'ok'
  };
  final List<Map<String, Object?>> puts = [];
  final List<String> paths = [];

  final providers = [
    _provider('local', 'Yerel model', cloud: false),
    _provider('anthropic', 'Claude', model: 'claude-x'),
    _provider('gemini', 'Gemini', available: false, reason: 'Disabled on the server'),
    _provider('custom', 'Custom (OpenAI compatible)'),
  ];

  AssistantProviderClient get client =>
      AssistantProviderClient(httpClient: MockClient((req) async {
        paths.add('${req.method} ${req.url.path}');
        switch ('${req.method} ${req.url.path}') {
          case 'GET /assistant/providers':
            return _json(200, {'providers': providers});
          case 'GET /assistant/provider':
            return _json(200, choice);
          case 'PUT /assistant/provider':
            final body = jsonDecode(req.body) as Map<String, Object?>;
            puts.add(body);
            if (putStatus != 200) return _json(putStatus, putBody);
            final key = body['api_key'];
            final had = choice['has_key'] == true;
            choice = _choice(
              provider: body['provider']! as String,
              model: body['model'] as String?,
              hasKey: key == '' ? false : (key != null || had),
              hint: key == ''
                  ? null
                  : (key != null ? 'wxyz' : choice['key_hint'] as String?),
              consent: body['consent_cloud']! as bool,
              position: body['allow_position']! as bool,
            );
            return _json(200, choice);
          case 'GET /assistant/models':
            if (modelsStatus != 200) {
              return _json(modelsStatus, {'detail': 'provider error'});
            }
            return _json(200, {
              'models': [
                {'id': 'claude-x', 'label': 'Claude X'},
                {'id': 'claude-y', 'label': 'Claude Y'},
              ]
            });
          case 'POST /assistant/provider/test':
            return _json(200, testBody);
        }
        return _json(404, {'detail': 'Not Found'});
      }));
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpScreen(WidgetTester tester, _Server server) async {
  _tall(tester);
  await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: AssistantModelScreen(
          baseUrl: _base, token: 'tok', client: server.client)));
  await tester.pumpAndSettle();
}

TextField _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key)));

Future<void> _chooseClaude(WidgetTester tester, {bool accept = true}) async {
  await tester.tap(find.byKey(const ValueKey('provider-anthropic')));
  await tester.pumpAndSettle();
  if (accept) {
    await tester.tap(find.byKey(const ValueKey('consent-accept')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('lists providers, local selected, unavailable one disabled',
      (tester) async {
    final server = _Server();
    await _pumpScreen(tester, server);
    expect(find.text('Yerel model'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Disabled on the server'), findsOneWidget);
    // No key/model fields for the local model.
    expect(find.byKey(const ValueKey('provider-key')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('provider-gemini')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('consent-accept')), findsNothing);
    expect(find.byKey(const ValueKey('provider-key')), findsNothing);
    final tile =
        tester.widget<ListTile>(find.byKey(const ValueKey('provider-gemini')));
    expect(tile.enabled, isFalse);
  });

  testWidgets(
      'choosing a cloud provider opens the consent sheet; cancel keeps local',
      (tester) async {
    final server = _Server();
    await _pumpScreen(tester, server);
    await _chooseClaude(tester, accept: false);
    expect(find.textContaining('Your question and the ride data the server computed are sent to'),
        findsOneWidget);
    expect(find.textContaining('billed to your own Claude account'),
        findsOneWidget);
    expect(find.text('Also send position data'), findsOneWidget);
    final sw = tester.widget<Switch>(find.descendant(
        of: find.byKey(const ValueKey('consent-position')),
        matching: find.byType(Switch)));
    expect(sw.value, isFalse);

    await tester.tap(find.byKey(const ValueKey('consent-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('provider-key')), findsNothing);
    expect(server.puts, isEmpty);
  });

  testWidgets(
      'saving sends consent, position off by default, key once then cleared',
      (tester) async {
    final server = _Server();
    await _pumpScreen(tester, server);
    await _chooseClaude(tester);
    await tester.enterText(
        find.byKey(const ValueKey('provider-key')), 'sk-secret-wxyz');
    await tester.tap(find.byKey(const ValueKey('save-provider')));
    await tester.pumpAndSettle();

    expect(server.puts.single['provider'], 'anthropic');
    expect(server.puts.single['api_key'], 'sk-secret-wxyz');
    expect(server.puts.single['consent_cloud'], true);
    expect(server.puts.single['allow_position'], false);
    // The key is gone from the field and nowhere on screen; only the hint.
    expect(_field(tester, 'provider-key').controller!.text, isEmpty);
    expect(find.textContaining('sk-secret'), findsNothing);
    expect(find.text('Saved key ••••wxyz'), findsOneWidget);
    expect(find.text('Saved.'), findsOneWidget);
    // Models were fetched after the key was set: a dropdown now.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(server.paths, contains('GET /assistant/models'));
  });

  testWidgets('position switch in the consent sheet is sent when turned on',
      (tester) async {
    final server = _Server();
    await _pumpScreen(tester, server);
    await tester.tap(find.byKey(const ValueKey('provider-anthropic')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('consent-position')));
    await tester.tap(find.byKey(const ValueKey('consent-accept')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-provider')));
    await tester.pumpAndSettle();
    expect(server.puts.single['allow_position'], true);
    expect(server.puts.single.containsKey('api_key'), isFalse);
  });

  testWidgets('saved key is never prefilled; delete sends an empty key',
      (tester) async {
    final server = _Server(
        choice: _choice(
            provider: 'anthropic',
            model: 'claude-x',
            hasKey: true,
            hint: 'ab12',
            consent: true));
    await _pumpScreen(tester, server);
    expect(_field(tester, 'provider-key').controller!.text, isEmpty);
    expect(find.text('Saved key ••••ab12'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-key')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(server.puts.single['api_key'], '');
    expect(find.textContaining('Saved key'), findsNothing);
    expect(find.text('Key deleted.'), findsOneWidget);
  });

  testWidgets('models 502 falls back to a free-text model field',
      (tester) async {
    final server = _Server(
        choice: _choice(
            provider: 'anthropic',
            model: 'claude-x',
            hasKey: true,
            hint: 'ab12',
            consent: true))
      ..modelsStatus = 502;
    await _pumpScreen(tester, server);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(_field(tester, 'model-text').controller!.text, 'claude-x');
  });

  testWidgets('custom provider shows the base URL field and sends it',
      (tester) async {
    final server = _Server();
    await _pumpScreen(tester, server);
    expect(find.byKey(const ValueKey('provider-url')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('provider-custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('consent-accept')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('provider-url')), findsOneWidget);
    // Save is blocked until an address is given.
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-provider')))
            .onPressed,
        isNull);
    await tester.enterText(
        find.byKey(const ValueKey('provider-url')), 'https://llm.example/v1');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-provider')));
    await tester.pumpAndSettle();
    expect(server.puts.single['base_url'], 'https://llm.example/v1');
  });

  testWidgets('403 insecure transport explains HTTPS and the CLI command',
      (tester) async {
    final server = _Server()
      ..putStatus = 403
      ..putBody = {'detail': 'insecure transport'};
    await _pumpScreen(tester, server);
    await _chooseClaude(tester);
    await tester.enterText(find.byKey(const ValueKey('provider-key')), 'sk-x');
    await tester.tap(find.byKey(const ValueKey('save-provider')));
    await tester.pumpAndSettle();
    expect(
        find.textContaining(
            'The key can only be entered over a secure connection (HTTPS) or on the Pi'),
        findsOneWidget);
    expect(
        find.textContaining(
            'vehicle-server user set-llm <user> --provider <id>'),
        findsOneWidget);
    expect(_field(tester, 'provider-key').controller!.text, isEmpty);
  });

  for (final c in [
    (400, 'consent required', 'need your consent'),
    (503, 'cloud providers disabled', 'Cloud providers are turned off'),
    (422, 'bad input', 'did not accept the input'),
    (502, 'provider error', 'provider returned an error'),
  ]) {
    testWidgets('save ${c.$1} shows a localized message', (tester) async {
      final server = _Server()
        ..putStatus = c.$1
        ..putBody = {'detail': c.$2};
      await _pumpScreen(tester, server);
      await _chooseClaude(tester);
      await tester.tap(find.byKey(const ValueKey('save-provider')));
      await tester.pumpAndSettle();
      expect(find.textContaining(c.$3), findsOneWidget);
    });
  }

  testWidgets(
      'dismissing the consent sheet leaves local selected, so no cloud save exists',
      (tester) async {
    final server = _Server();
    await _pumpScreen(tester, server);
    await _chooseClaude(tester, accept: false);
    await tester.tap(find.byKey(const ValueKey('consent-cancel')));
    await tester.pumpAndSettle();
    // Still on local: nothing cloud selected, so no cloud PUT can be built.
    await tester.tap(find.byKey(const ValueKey('save-provider')));
    await tester.pumpAndSettle();
    expect(server.puts.single['provider'], 'local');
    expect(server.puts.single['consent_cloud'], false);
    expect(server.puts.single['allow_position'], false);
  });

  testWidgets('connection test shows latency', (tester) async {
    final server = _Server(
        choice: _choice(
            provider: 'anthropic',
            model: 'claude-x',
            hasKey: true,
            hint: 'ab12',
            consent: true));
    await _pumpScreen(tester, server);
    await tester.tap(find.byKey(const ValueKey('test-provider')));
    await tester.pumpAndSettle();
    expect(find.textContaining('The connection works (321 ms)'), findsOneWidget);

    server.testBody = {'ok': false, 'latency_ms': 0, 'detail': 'bad key'};
    await tester.tap(find.byKey(const ValueKey('test-provider')));
    await tester.pumpAndSettle();
    expect(find.textContaining('The connection failed: bad key'), findsOneWidget);
  });

  group('settings integration', () {
    Future<void> pumpSettings(WidgetTester tester, _Server server,
        {bool account = true}) async {
      _tall(tester);
      HostResolver.invalidate();
      final store = signedInStore(baseUrl: _base);
      if (account) {
        await AuthStore(store.hosts).saveAccount('h1',
            const AccountInfo(username: 'rider', vehicles: <AccountVehicle>[]));
      }
      await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(store: store, assistantClient: server.client)));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the default summary and opens the screen',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final server = _Server();
      await pumpSettings(tester, server);
      expect(find.text('Local model (default)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('assistant-model-row')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('provider-anthropic')), findsOneWidget);
    });

    testWidgets('summary names provider and model', (tester) async {
      final server = _Server(
          choice: _choice(
              provider: 'anthropic',
              model: 'claude-x',
              hasKey: true,
              consent: true));
      await pumpSettings(tester, server);
      expect(
          find.text('Claude · claude-x', skipOffstage: false), findsOneWidget);
    });

    testWidgets('404 hides the section (older server)', (tester) async {
      _tall(tester);
      final client = AssistantProviderClient(
          httpClient:
              MockClient((_) async => _json(404, {'detail': 'Not Found'})));
      HostResolver.invalidate();
      final store = signedInStore(baseUrl: _base);
      await AuthStore(store.hosts).saveAccount('h1',
          const AccountInfo(username: 'rider', vehicles: <AccountVehicle>[]));
      await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(store: store, assistantClient: client)));
      await tester.pumpAndSettle();
      expect(find.text('Assistant model', skipOffstage: false), findsNothing);
    });

    testWidgets('hidden when not signed in, without calling the server',
        (tester) async {
      final server = _Server();
      await pumpSettings(tester, server, account: false);
      expect(find.text('Assistant model', skipOffstage: false), findsNothing);
      expect(server.paths, isEmpty);
    });
  });
}
