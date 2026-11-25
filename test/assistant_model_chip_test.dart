import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/models/host.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/assistant_provider_client.dart';
import 'package:vehicle_mobile/services/chat_client.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/ui/assistant/assistant_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

import 'support/memory_secrets.dart';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

const _host = Host(id: 'h1', name: 'Bike', baseUrl: 'https://bike.example.com');

Map<String, Object?> _prov(String id, String label, String model,
        {bool available = true, String? reason}) =>
    {
      'id': id,
      'label': label,
      'kind': 'local',
      'cloud': id != 'local',
      'default_model': model,
      'has_models_endpoint': false,
      'data_note': '',
      'available': available,
      'unavailable_reason': reason,
    };

AssistantProviderClient _providerClient(
    {required String provider,
    String? model,
    int currentStatus = 200,
    List<Map<String, Object?>>? providers}) {
  return AssistantProviderClient(httpClient: MockClient((request) async {
    final path = request.url.path;
    if (path == '/assistant/provider') {
      return currentStatus == 200
          ? _json(200, {'provider': provider, 'model': model})
          : http.Response('{"detail":"Not Found"}', currentStatus);
    }
    if (path == '/assistant/providers') {
      return _json(200, {
        'providers': providers ??
            [
              _prov('local', 'Local', 'qwen2.5-1.5b'),
              _prov('google', 'Google Gemini', 'gemini-2.5-flash'),
            ]
      });
    }
    if (path == '/assistant/models') return _json(200, {'models': []});
    return http.Response('', 404);
  }));
}

Future<AppSettingsStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  HostResolver.invalidate();
  final store = AppSettingsStore(secrets: MemorySecrets());
  await store.hosts.saveHosts([_host]);
  await store.hosts.writeToken('h1', 'tok');
  return store;
}

Future<void> _pump(WidgetTester tester, AppSettingsStore store,
    {required ChatClient chat,
    required AssistantProviderClient provider}) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: AssistantScreen(
        settingsStore: store, client: chat, providerClient: provider),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byIcon(Icons.arrow_upward));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

ChatClient _chat(Map<String, Object?> body) =>
    ChatClient(httpClient: MockClient((_) async => _json(200, body)));

void main() {
  testWidgets('header chip shows the provider label and the default model',
      (tester) async {
    final store = await _store();
    await _pump(tester, store,
        chat: _chat({'answer': 'x', 'source': 'llm'}),
        provider: _providerClient(provider: 'local'));
    expect(find.text('Local · qwen2.5-1.5b'), findsOneWidget);
  });

  testWidgets('chip shows the chosen model and opens the model screen',
      (tester) async {
    final store = await _store();
    await _pump(tester, store,
        chat: _chat({'answer': 'x', 'source': 'llm'}),
        provider: _providerClient(provider: 'google', model: 'gemini-2.5-pro'));
    expect(find.text('Google Gemini · gemini-2.5-pro'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('active-model-chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('provider-google')), findsOneWidget);
    // The key help is visible once a cloud provider is selected.
    expect(find.byKey(const ValueKey('key-help')), findsOneWidget);
  });

  testWidgets('chip is hidden on an older server (404)', (tester) async {
    final store = await _store();
    await _pump(tester, store,
        chat: _chat({'answer': 'x', 'source': 'llm'}),
        provider: _providerClient(provider: 'local', currentStatus: 404));
    expect(find.byKey(const ValueKey('active-model-chip')), findsNothing);
  });

  testWidgets('caption names the model that answered', (tester) async {
    final store = await _store();
    await _pump(tester, store,
        chat: _chat({
          'answer': 'Hello',
          'source': 'llm',
          'model': {
            'provider_id': 'google',
            'label': 'Google Gemini',
            'model': 'gemini-2.5-flash'
          },
        }),
        provider: _providerClient(provider: 'local'));
    await _ask(tester, 'hi');
    expect(find.byKey(const ValueKey('model-caption')), findsOneWidget);
    expect(find.text('Google Gemini · gemini-2.5-flash'), findsOneWidget);
  });

  testWidgets('caption says template when model is null', (tester) async {
    final store = await _store();
    await _pump(tester, store,
        chat: _chat({'answer': 'Fixed', 'source': 'template', 'model': null}),
        provider: _providerClient(provider: 'local'));
    await _ask(tester, 'hi');
    expect(find.text('Template answer (no model)'), findsOneWidget);
  });

  testWidgets('older server without the model field shows no LLM caption',
      (tester) async {
    final store = await _store();
    await _pump(tester, store,
        chat: _chat({'answer': 'Hello', 'source': 'llm'}),
        provider: _providerClient(provider: 'local'));
    await _ask(tester, 'hi');
    expect(find.text('Hello'), findsOneWidget);
    expect(find.byKey(const ValueKey('model-caption')), findsNothing);
  });

  testWidgets('no caption on error and failure bubbles', (tester) async {
    final store = await _store();
    await _pump(tester, store,
        chat: _chat({
          'answer': 'Boom',
          'source': 'error',
          'model': {'provider_id': 'local', 'label': 'Local', 'model': 'm'},
        }),
        provider: _providerClient(provider: 'local'));
    await _ask(tester, 'hi');
    expect(find.text('Boom'), findsOneWidget);
    expect(find.byKey(const ValueKey('model-caption')), findsNothing);
  });

  testWidgets('model screen shows the unavailable reason of a provider',
      (tester) async {
    final store = await _store();
    await _pump(tester, store,
        chat: _chat({'answer': 'x', 'source': 'llm'}),
        provider: _providerClient(provider: 'local', providers: [
          _prov('local', 'Local', 'q'),
          _prov('google', 'Google Gemini', 'g',
              available: false, reason: 'Cloud providers are disabled'),
        ]));
    await tester.tap(find.byKey(const ValueKey('active-model-chip')));
    await tester.pumpAndSettle();
    expect(find.text('Cloud providers are disabled'), findsOneWidget);
  });
}
