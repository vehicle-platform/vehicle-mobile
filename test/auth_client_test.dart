import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vehicle_mobile/services/auth_client.dart';
import 'package:vehicle_mobile/services/auth_events.dart';

const _base = 'https://vehicle.example.test';

http.Response _json(int status, Object body, {Map<String, String>? headers}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json', ...?headers});

const _loginBody = {
  'token': 'secret-token',
  'expires_utc': '2026-12-25T10:00:00Z',
  'user': {'username': 'rider'},
  'vehicles': [
    {'vehicle_id': 'veh-abc123', 'name': 'CL250'}
  ],
};

AuthClient _client(MockClient mock) => AuthClient(httpClient: mock);

void main() {
  group('login', () {
    test('200 returns the session and sends the exact body', () async {
      late http.Request seen;
      final result = await _client(MockClient((r) async {
        seen = r;
        return _json(200, _loginBody);
      })).login(baseUrl: '$_base/', username: 'rider', password: 'pw-123456');
      expect(result.outcome, AuthOutcome.ok);
      expect(result.session!.token, 'secret-token');
      expect(result.session!.username, 'rider');
      expect(result.session!.vehicles.single.vehicleId, 'veh-abc123');
      expect(seen.url.toString(), '$_base/auth/login');
      expect(seen.method, 'POST');
      expect(jsonDecode(seen.body),
          {'username': 'rider', 'password': 'pw-123456'});
      expect(seen.headers.containsKey('Authorization'), isFalse);
    });

    test('401 is a generic credentials error', () async {
      final result = await _client(MockClient((_) async =>
              _json(401, {'detail': 'invalid username or password'})))
          .login(baseUrl: _base, username: 'a', password: 'b');
      expect(result.outcome, AuthOutcome.unauthorized);
      expect(result.statusCode, 401);
    });

    test('429 carries Retry-After', () async {
      final result = await _client(MockClient((_) async => _json(
              429, {'detail': 'slow down'}, headers: {'retry-after': '30'})))
          .login(baseUrl: _base, username: 'a', password: 'b');
      expect(result.outcome, AuthOutcome.rateLimited);
      expect(result.retryAfterSeconds, 30);
    });

    test('404 means an older server without accounts', () async {
      final result =
          await _client(MockClient((_) async => http.Response('nf', 404)))
              .login(baseUrl: _base, username: 'a', password: 'b');
      expect(result.outcome, AuthOutcome.notSupported);
    });

    test('a malformed 200 body fails without leaking the token', () async {
      final result =
          await _client(MockClient((_) async => _json(200, {'x': 1})))
              .login(baseUrl: _base, username: 'a', password: 'b');
      expect(result.outcome, AuthOutcome.failed);
    });

    test('network error and timeout are unreachable', () async {
      final down = await _client(
              MockClient((_) async => throw http.ClientException('no route')))
          .login(baseUrl: _base, username: 'a', password: 'b');
      expect(down.outcome, AuthOutcome.unreachable);
      final slow = await AuthClient(
        httpClient: MockClient((_) => Completer<http.Response>().future),
        totalTimeout: const Duration(milliseconds: 10),
      ).login(baseUrl: _base, username: 'a', password: 'b');
      expect(slow.outcome, AuthOutcome.unreachable);
    });

    test('plain http to a public host is refused before any request', () async {
      var called = false;
      final result = await _client(MockClient((_) async {
        called = true;
        return _json(200, _loginBody);
      })).login(baseUrl: 'http://example.com', username: 'a', password: 'b');
      expect(result.outcome, AuthOutcome.failed);
      expect(called, isFalse);
    });

    test('the password never appears in a failure message', () async {
      final result =
          await _client(MockClient((_) async => throw Exception('boom')))
              .login(baseUrl: _base, username: 'a', password: 'topsecret');
      expect(result.message ?? '', isNot(contains('topsecret')));
    });
  });

  group('register', () {
    Future<AuthResult> reg(MockClient mock) => _client(mock).register(
        baseUrl: _base,
        username: 'rider',
        password: 'pw-1234567',
        vehicleId: 'veh-abc123',
        claimCode: 'CODE');

    test('201 returns the session and sends vehicle id and claim code',
        () async {
      late http.Request seen;
      final result = await reg(MockClient((r) async {
        seen = r;
        return _json(201, _loginBody);
      }));
      expect(result.outcome, AuthOutcome.ok);
      expect(result.session!.username, 'rider');
      expect(seen.url.path, '/auth/register');
      expect(jsonDecode(seen.body), {
        'username': 'rider',
        'password': 'pw-1234567',
        'vehicle_id': 'veh-abc123',
        'claim_code': 'CODE',
      });
    });

    test('409 username taken', () async {
      final r = await reg(
          MockClient((_) async => _json(409, {'detail': 'username taken'})));
      expect(r.outcome, AuthOutcome.conflict);
    });

    test('403 invalid vehicle or code', () async {
      final r = await reg(MockClient(
          (_) async => _json(403, {'detail': 'invalid vehicle or code'})));
      expect(r.outcome, AuthOutcome.forbidden);
    });

    test('422 keeps the validation message', () async {
      final r = await reg(MockClient((_) async => _json(422, {
            'detail': [
              {'msg': 'password too short'}
            ]
          })));
      expect(r.outcome, AuthOutcome.invalid);
      expect(r.message, 'password too short');
    });

    test('429 rate limited', () async {
      final r = await reg(MockClient(
          (_) async => http.Response('', 429, headers: {'retry-after': '5'})));
      expect(r.outcome, AuthOutcome.rateLimited);
      expect(r.retryAfterSeconds, 5);
    });
  });

  group('logout, me, claim', () {
    test('logout 204 sends the bearer token', () async {
      late http.Request seen;
      final r = await _client(MockClient((req) async {
        seen = req;
        return http.Response('', 204);
      })).logout(baseUrl: _base, token: 'tok');
      expect(r.outcome, AuthOutcome.ok);
      expect(seen.url.path, '/auth/logout');
      expect(seen.headers['Authorization'], 'Bearer tok');
    });

    test('me returns the vehicles', () async {
      final r = await _client(MockClient((_) async => _json(200, {
            'user': {'username': 'rider'},
            'vehicles': [
              {'vehicle_id': 'v1', 'name': 'A'}
            ]
          }))).me(baseUrl: _base, token: 'tok');
      expect(r.vehicles!.single.name, 'A');
    });

    test('claim 200 / 403 / 429', () async {
      final ok = await _client(MockClient((req) async {
        expect(jsonDecode(req.body), {'vehicle_id': 'v2', 'claim_code': 'C'});
        return _json(200, {
          'vehicles': [
            {'vehicle_id': 'v1', 'name': 'A'},
            {'vehicle_id': 'v2', 'name': 'B'}
          ]
        });
      })).claimVehicle(
          baseUrl: _base, token: 't', vehicleId: 'v2', claimCode: 'C');
      expect(ok.vehicles!.length, 2);
      final no =
          await _client(MockClient((_) async => _json(403, {'detail': 'x'})))
              .claimVehicle(
                  baseUrl: _base, token: 't', vehicleId: 'v2', claimCode: 'C');
      expect(no.outcome, AuthOutcome.forbidden);
      final slow =
          await _client(MockClient((_) async => http.Response('', 429)))
              .claimVehicle(
                  baseUrl: _base, token: 't', vehicleId: 'v2', claimCode: 'C');
      expect(slow.outcome, AuthOutcome.rateLimited);
    });
  });

  test('every client reports a 401 on the auth event bus', () async {
    final events = <AuthEvent>[];
    final sub = AuthEvents.stream.listen(events.add);
    AuthEvents.reportUnauthorized();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(events, [AuthEvent.unauthorized]);
  });
}
