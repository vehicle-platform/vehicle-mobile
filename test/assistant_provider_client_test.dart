import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vehicle_mobile/services/assistant_provider_client.dart';
import 'package:vehicle_mobile/services/auth_events.dart';

const _base = 'https://vehicle.example.test';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

const _choice = {
  'provider': 'anthropic',
  'model': 'm1',
  'base_url': null,
  'has_key': true,
  'key_hint': 'ab12',
  'consent_cloud': true,
  'allow_position': false,
  'updated_utc': '2026-11-25T10:00:00Z',
};

AssistantProviderClient _client(MockClient m) =>
    AssistantProviderClient(httpClient: m);

Future<ProviderResult<Object>> _save(MockClient m, {String? apiKey}) =>
    _client(m).save(
        baseUrl: _base,
        token: 'tok',
        provider: 'anthropic',
        model: 'm1',
        apiKey: apiKey,
        consentCloud: true,
        allowPosition: false);

void main() {
  test('providers parses the catalogue and sends the bearer token', () async {
    late http.Request seen;
    final r = await _client(MockClient((req) async {
      seen = req;
      return _json(200, {
        'providers': [
          {
            'id': 'local',
            'label': 'Yerel',
            'kind': 'local',
            'cloud': false,
            'base_url': null,
            'default_model': null,
            'has_models_endpoint': false,
            'data_note': 'x',
            'available': true,
            'unavailable_reason': null,
          },
          {
            'id': 'anthropic',
            'label': 'Claude',
            'kind': 'anthropic',
            'cloud': true,
            'base_url': null,
            'default_model': 'm1',
            'has_models_endpoint': true,
            'data_note': 'y',
            'available': false,
            'unavailable_reason': 'disabled',
          },
        ]
      });
    })).providers(baseUrl: '$_base/', token: 'tok');
    expect(r.outcome, ProviderOutcome.ok);
    expect(r.value!.length, 2);
    expect(r.value![1].available, isFalse);
    expect(r.value![1].unavailableReason, 'disabled');
    expect(seen.url.toString(), '$_base/assistant/providers');
    expect(seen.headers['Authorization'], 'Bearer tok');
  });

  test('current parses the choice', () async {
    final r = await _client(MockClient((_) async => _json(200, _choice)))
        .current(baseUrl: _base, token: 'tok');
    expect(r.value!.keyHint, 'ab12');
    expect(r.value!.consentCloud, isTrue);
  });

  test('save sends the exact body: key omitted keeps, "" deletes', () async {
    late http.Request seen;
    final m = MockClient((req) async {
      seen = req;
      return _json(200, _choice);
    });
    expect((await _save(m)).outcome, ProviderOutcome.ok);
    expect(seen.method, 'PUT');
    expect(seen.url.path, '/assistant/provider');
    expect(jsonDecode(seen.body), {
      'provider': 'anthropic',
      'model': 'm1',
      'consent_cloud': true,
      'allow_position': false,
    });
    await _save(m, apiKey: '');
    expect(jsonDecode(seen.body)['api_key'], '');
    await _save(m, apiKey: 'sk-secret');
    expect(jsonDecode(seen.body)['api_key'], 'sk-secret');
  });

  test('base_url is only sent for custom', () async {
    late http.Request seen;
    final m = MockClient((req) async {
      seen = req;
      return _json(200, {..._choice, 'provider': 'custom'});
    });
    await _client(m).save(
        baseUrl: _base,
        token: 'tok',
        provider: 'custom',
        providerBaseUrl: 'https://x.example/v1',
        consentCloud: true,
        allowPosition: false);
    expect(jsonDecode(seen.body)['base_url'], 'https://x.example/v1');
    await _client(m).save(
        baseUrl: _base,
        token: 'tok',
        provider: 'anthropic',
        providerBaseUrl: 'https://x.example/v1',
        consentCloud: true,
        allowPosition: false);
    expect(jsonDecode(seen.body).containsKey('base_url'), isFalse);
  });

  group('status mapping', () {
    final cases = {
      400: (ProviderOutcome.consentRequired, {'detail': 'consent required'}),
      403: (
        ProviderOutcome.insecureTransport,
        {'detail': 'insecure transport'}
      ),
      404: (ProviderOutcome.notSupported, {'detail': 'Not Found'}),
      422: (ProviderOutcome.invalid, {'detail': 'bad'}),
      502: (ProviderOutcome.providerError, {'detail': 'provider error'}),
      503: (
        ProviderOutcome.cloudDisabled,
        {'detail': 'cloud providers disabled'}
      ),
      500: (ProviderOutcome.failed, {'detail': 'boom'}),
    };
    cases.forEach((status, expected) {
      test('$status -> ${expected.$1}', () async {
        final r = await _save(
            MockClient((_) async => _json(status, expected.$2)),
            apiKey: 'sk-secret');
        expect(r.outcome, expected.$1);
        expect(r.statusCode, status);
        expect(r.message ?? '', isNot(contains('sk-secret')));
      });
    });
  });

  test('401 reports the session end', () async {
    final events = <AuthEvent>[];
    final sub = AuthEvents.stream.listen(events.add);
    final r =
        await _client(MockClient((_) async => _json(401, {'detail': 'x'})))
            .models(baseUrl: _base, token: 'tok');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(r.outcome, ProviderOutcome.unauthorized);
    expect(events, contains(AuthEvent.unauthorized));
  });

  test('models 200 and 502', () async {
    final ok = await _client(MockClient((_) async => _json(200, {
          'models': [
            {'id': 'a', 'label': 'A'},
            {'id': 'b', 'label': 'B'}
          ]
        }))).models(baseUrl: _base, token: 'tok');
    expect(ok.value!.map((m) => m.id), ['a', 'b']);
    final bad = await _client(
            MockClient((_) async => _json(502, {'detail': 'provider error'})))
        .models(baseUrl: _base, token: 'tok');
    expect(bad.outcome, ProviderOutcome.providerError);
  });

  test('test route result', () async {
    late http.Request seen;
    final r = await _client(MockClient((req) async {
      seen = req;
      return _json(200, {'ok': true, 'latency_ms': 412, 'detail': 'fine'});
    })).test(baseUrl: _base, token: 'tok');
    expect(seen.method, 'POST');
    expect(seen.url.path, '/assistant/provider/test');
    expect(r.value!.ok, isTrue);
    expect(r.value!.latencyMs, 412);
  });

  test('unreachable, malformed body and refused URL', () async {
    final down =
        await _client(MockClient((_) async => throw TimeoutException('t')))
            .current(baseUrl: _base, token: 'tok');
    expect(down.outcome, ProviderOutcome.unreachable);
    final bad = await _client(MockClient((_) async => _json(200, [1])))
        .current(baseUrl: _base, token: 'tok');
    expect(bad.outcome, ProviderOutcome.failed);
    final refused = await _client(MockClient((_) async => _json(200, _choice)))
        .current(baseUrl: 'http://203.0.113.9:8000', token: 'tok');
    expect(refused.outcome, ProviderOutcome.failed);
  });
}
