import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vehicle_mobile/services/assistant_provider_client.dart';
import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:vehicle_mobile/services/authed_json_client.dart';
import 'package:vehicle_mobile/services/conversations_client.dart';
import 'package:vehicle_mobile/services/notifications_client.dart';

const _base = 'https://vehicle.example.test';

AuthedJsonClient _api(MockClient m, {Duration? timeout}) => AuthedJsonClient(
    httpClient: m,
    connectTimeout: const Duration(seconds: 1),
    totalTimeout: timeout ?? const Duration(seconds: 5));

ConversationsClient _conv(MockClient m, {Duration? timeout}) =>
    ConversationsClient(
        httpClient: m, totalTimeout: timeout ?? const Duration(seconds: 5));

Future<ConvResult<ConversationPage>> _list(MockClient m, {Duration? timeout}) =>
    _conv(m, timeout: timeout).list(baseUrl: _base, token: 'tok');

void main() {
  group('AuthedJsonClient', () {
    test('sends bearer, JSON body and query; parses a 200', () async {
      late http.Request seen;
      final r = await _api(MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode({'n': 3}), 200);
      })).call<int>('PUT', '$_base/', 'tok', '/x',
          query: {'a': '1'},
          body: {'k': 'v'},
          parse: (j) => (j as Map)['n'] as int);
      expect(r.ok, isTrue);
      expect(r.value, 3);
      expect(seen.url.toString(), '$_base/x?a=1');
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(seen.headers['Content-Type'], 'application/json');
      expect(jsonDecode(seen.body), {'k': 'v'});
    });

    test('a 204 without parse is a success with no value', () async {
      final r = await _api(MockClient((_) async => http.Response('', 204)))
          .call<void>('DELETE', _base, 'tok', '/x', okStatuses: {200, 204});
      expect(r.ok, isTrue);
      expect(r.statusCode, 204);
    });

    test('a malformed or unparsable 200 is a failure with status 200',
        () async {
      final bad = await _api(MockClient((_) async => http.Response('{', 200)))
          .call<int>('GET', _base, 'tok', '/x', parse: (_) => 1);
      expect(bad.ok, isFalse);
      expect(bad.statusCode, 200);
      final nul = await _api(MockClient((_) async => http.Response('{}', 200)))
          .call<int>('GET', _base, 'tok', '/x', parse: (_) => null);
      expect(nul.ok, isFalse);
      expect(nul.message, 'malformed response');
    });

    test('a network error and a timeout are unreachable, no status', () async {
      final net = await _api(MockClient((_) async {
        throw http.ClientException('no route');
      })).call<int>('GET', _base, 'tok', '/x', parse: (_) => 1);
      expect(net.unreachable, isTrue);
      expect(net.statusCode, isNull);
      final slow = await _api(
        MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 20),
      ).call<int>('GET', _base, 'tok', '/x', parse: (_) => 1);
      expect(slow.unreachable, isTrue);
    });

    test('the token is never sent over plain http to a public host', () async {
      var sent = false;
      final r = await _api(MockClient((_) async {
        sent = true;
        return http.Response('{}', 200);
      })).call<int>('GET', 'http://example.com', 'tok', '/x', parse: (_) => 1);
      expect(sent, isFalse);
      expect(r.ok, isFalse);
      expect(r.statusCode, isNull);
    });

    test('a 401 is reported on AuthEvents, other errors are not', () async {
      final events = <AuthEvent>[];
      final sub = AuthEvents.stream.listen(events.add);
      addTearDown(sub.cancel);
      final r401 = await _api(MockClient((_) async => http.Response('', 401)))
          .call<int>('GET', _base, 'tok', '/x', parse: (_) => 1);
      await _api(MockClient((_) async => http.Response('', 500)))
          .call<int>('GET', _base, 'tok', '/x', parse: (_) => 1);
      await Future<void>.delayed(Duration.zero);
      expect(r401.statusCode, 401);
      expect(events, [AuthEvent.unauthorized]);
    });
  });

  group('ConversationsClient status mapping', () {
    final cases = <int, ConvOutcome>{
      401: ConvOutcome.unauthorized,
      403: ConvOutcome.forbidden,
      404: ConvOutcome.notFound,
      409: ConvOutcome.conflict,
      422: ConvOutcome.invalid,
      500: ConvOutcome.failed,
      503: ConvOutcome.failed,
    };
    cases.forEach((status, outcome) {
      test('$status maps to $outcome', () async {
        final r = await _list(MockClient(
            (_) async => http.Response(jsonEncode({'detail': 'why'}), status)));
        expect(r.outcome, outcome);
        expect(r.statusCode, status);
        expect(r.isSuccess, isFalse);
        expect(r.message, 'why');
      });
    });

    test('a server error without a body still has a message', () async {
      final r = await _list(MockClient((_) async => http.Response('', 500)));
      expect(r.message, 'HTTP 500');
      expect(r.isTransient, isTrue);
    });

    test('network error and timeout are unreachable (transient)', () async {
      final net = await _list(MockClient((_) async {
        throw http.ClientException('down');
      }));
      expect(net.outcome, ConvOutcome.unreachable);
      expect(net.isTransient, isTrue);
      final slow = await _list(
          MockClient((_) => Completer<http.Response>().future),
          timeout: const Duration(milliseconds: 20));
      expect(slow.outcome, ConvOutcome.unreachable);
    });

    test('a 401 emits AuthEvents.unauthorized', () async {
      final events = <AuthEvent>[];
      final sub = AuthEvents.stream.listen(events.add);
      addTearDown(sub.cancel);
      await _list(MockClient((_) async => http.Response('', 401)));
      await Future<void>.delayed(Duration.zero);
      expect(events, [AuthEvent.unauthorized]);
    });

    test('403 and 404 are not transient, 404 is not "notSupported"', () async {
      final r403 = await _list(MockClient((_) async => http.Response('', 403)));
      final r404 = await _list(MockClient((_) async => http.Response('', 404)));
      expect(r403.isTransient, isFalse);
      expect(r404.isTransient, isFalse);
      expect(r404.outcome, ConvOutcome.notFound);
    });

    test('delete accepts 204 and 200, a 404 is a failure', () async {
      for (final status in [204, 200]) {
        final r = await _conv(MockClient((_) async => http.Response('', status)))
            .deleteOne(baseUrl: _base, token: 'tok', id: 'a b');
        expect(r.isSuccess, isTrue);
      }
      late Uri url;
      final nf = await _conv(MockClient((req) async {
        url = req.url;
        return http.Response('', 404);
      })).deleteOne(baseUrl: _base, token: 'tok', id: 'a b');
      expect(nf.outcome, ConvOutcome.notFound);
      expect(url.path, '/conversations/a%20b');
    });
  });

  group('AssistantProviderClient keeps its mapping on the shared transport',
      () {
    Future<ProviderResult<Object>> call(int status) => AssistantProviderClient(
            httpClient: MockClient((_) async => http.Response('', status)))
        .current(baseUrl: _base, token: 'tok');

    test('status to outcome', () async {
      expect((await call(400)).outcome, ProviderOutcome.consentRequired);
      expect((await call(401)).outcome, ProviderOutcome.unauthorized);
      expect((await call(403)).outcome, ProviderOutcome.insecureTransport);
      expect((await call(404)).outcome, ProviderOutcome.notSupported);
      expect((await call(422)).outcome, ProviderOutcome.invalid);
      expect((await call(502)).outcome, ProviderOutcome.providerError);
      expect((await call(503)).outcome, ProviderOutcome.cloudDisabled);
      final other = await call(500);
      expect(other.outcome, ProviderOutcome.failed);
      expect(other.message, 'HTTP 500');
    });

    test('a 401 emits AuthEvents and the network is unreachable', () async {
      final events = <AuthEvent>[];
      final sub = AuthEvents.stream.listen(events.add);
      addTearDown(sub.cancel);
      await call(401);
      final down = await AssistantProviderClient(
          httpClient: MockClient((_) async {
        throw http.ClientException('down');
      })).current(baseUrl: _base, token: 'tok');
      await Future<void>.delayed(Duration.zero);
      expect(events, [AuthEvent.unauthorized]);
      expect(down.outcome, ProviderOutcome.unreachable);
    });
  });

  group('notifications locale', () {
    Future<String> query(String? locale) async {
      late Uri seen;
      await NotificationsClient(httpClient: MockClient((req) async {
        seen = req.url;
        return http.Response(jsonEncode({'notifications': [], 'latest_id': 0}),
            200);
      })).list(baseUrl: _base, token: 'tok', sinceId: 2, limit: 10, locale: locale);
      return seen.toString();
    }

    test('passes en and tr, anything else asks for en, none omits it',
        () async {
      expect(await query('tr'), '$_base/notifications?since_id=2&limit=10&locale=tr');
      expect(await query('en'), endsWith('&locale=en'));
      expect(await query('de'), endsWith('&locale=en'));
      expect(await query('TR'), endsWith('&locale=tr'));
      expect(await query(null), '$_base/notifications?since_id=2&limit=10');
    });
  });
}
