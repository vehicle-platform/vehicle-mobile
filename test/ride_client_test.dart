import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vehicle_mobile/models/ride_summary.dart';
import 'package:vehicle_mobile/services/ride_client.dart';

const ridesBody = {
  'columns': [
    {'name': 'ride_distance', 'unit': 'km'},
  ],
  'rows': [
    {
      'session_id': '20260105-100000-abcd',
      'created_utc': '2026-01-05T10:00:00Z',
      'values': {'ride_distance': 1.5},
      'flags': {'ride_distance': null},
    },
  ],
  'skipped': 0,
};

const summaryBody = {
  'session_id': '20260105-100000-abcd',
  'ride_definition': 'session',
  'defs_version': 'v0.19.1',
  'signals': [
    {
      'name': 'ride_distance',
      'status': 'computed',
      'unit': 'km',
      'range': [0.0, 2000.0],
      'kind': 'scalar',
      'value': 1.5,
      'flag': null,
    },
  ],
};

http.Response jsonResponse(Object body, int status) => http.Response(jsonEncode(body), status);

void main() {
  group('RideClient.listRides', () {
    test('sends one GET with the bearer token and an exact query', () async {
      late http.Request captured;
      final client = RideClient(httpClient: MockClient((request) async {
        captured = request;
        return jsonResponse(ridesBody, 200);
      }));

      final result = await client.listRides(
        baseUrl: 'https://vehicle-server.example.com',
        apiToken: 'secret-token',
        from: DateTime.utc(2026, 1, 5),
        to: DateTime.utc(2026, 1, 7),
        names: ['ride_distance', 'ride_time'],
      );

      expect(result.outcome, RideOutcome.ok);
      expect(result.isSuccess, isTrue);
      expect(result.data!.columns.single.name, 'ride_distance');
      expect(result.data!.rows.single.values['ride_distance'], 1.5);
      expect(captured.method, 'GET');
      expect(captured.headers['Authorization'], 'Bearer secret-token');
      expect(captured.headers['Accept'], 'application/json');
      expect(
        captured.url.toString(),
        'https://vehicle-server.example.com/rides?from=2026-01-05&to=2026-01-07&names=ride_distance%2Cride_time',
      );
    });

    test('strips a trailing slash and omits an empty query', () async {
      late Uri captured;
      final client = RideClient(httpClient: MockClient((request) async {
        captured = request.url;
        return jsonResponse(ridesBody, 200);
      }));

      await client.listRides(baseUrl: 'https://vehicle-server.example.com/', apiToken: 't');

      expect(captured.toString(), 'https://vehicle-server.example.com/rides');
    });
  });

  group('RideClient.getSummary', () {
    test('sends one GET to the summary route with the id as one path segment', () async {
      late http.Request captured;
      final client = RideClient(httpClient: MockClient((request) async {
        captured = request;
        return jsonResponse(summaryBody, 200);
      }));

      final result = await client.getSummary(
        baseUrl: 'https://vehicle-server.example.com/',
        apiToken: 'secret-token',
        sessionId: 'a/b',
      );

      expect(result.outcome, RideOutcome.ok);
      expect(result.data!.sessionId, '20260105-100000-abcd');
      expect(captured.method, 'GET');
      expect(captured.headers['Authorization'], 'Bearer secret-token');
      expect(captured.url.toString(), 'https://vehicle-server.example.com/sessions/a%2Fb/summary');
      expect(captured.url.pathSegments, ['sessions', 'a/b', 'summary']);
    });

    Future<RideResult<RideSummary>> withStatus(int status, {String body = '{}'}) {
      final client = RideClient(httpClient: MockClient((_) async => http.Response(body, status)));
      return client.getSummary(baseUrl: 'https://s', apiToken: 't', sessionId: 'id');
    }

    test('maps 401 to unauthorized', () async {
      final result = await withStatus(401);
      expect(result.outcome, RideOutcome.unauthorized);
      expect(result.statusCode, 401);
    });

    test('maps 404 to notFound and keeps the server message', () async {
      final result = await withStatus(404, body: jsonEncode({'detail': 'session has no ride summary'}));
      expect(result.outcome, RideOutcome.notFound);
      expect(result.statusCode, 404);
      expect(result.message, 'session has no ride summary');
    });

    test('maps 422 to invalid', () async {
      final result = await withStatus(422, body: jsonEncode({'detail': 'bad query'}));
      expect(result.outcome, RideOutcome.invalid);
      expect(result.message, 'bad query');
    });

    test('maps 503 to unavailable', () async {
      final result = await withStatus(503, body: jsonEncode({'detail': 'no API token configured'}));
      expect(result.outcome, RideOutcome.unavailable);
      expect(result.message, 'no API token configured');
    });

    test('maps other statuses to failed', () async {
      final result = await withStatus(500);
      expect(result.outcome, RideOutcome.failed);
      expect(result.statusCode, 500);
    });

    test('malformed JSON is a failure', () async {
      final result = await withStatus(200, body: '{not json');
      expect(result.outcome, RideOutcome.failed);
      expect(result.message, isNotEmpty);
    });

    test('a 200 with a missing required field is a failure naming the field', () async {
      final result = await withStatus(200, body: jsonEncode({
        'ride_definition': 'session',
        'defs_version': 'v0.19.1',
        'signals': <Object?>[],
      }));
      expect(result.outcome, RideOutcome.failed);
      expect(result.message, contains('session_id'));
    });

    test('a server that never answers times out as a failure', () async {
      final neverAnswers = Completer<http.Response>();
      final client = RideClient(
        httpClient: MockClient((_) => neverAnswers.future),
        totalTimeout: const Duration(milliseconds: 50),
      );
      final result = await client.getSummary(baseUrl: 'https://s', apiToken: 't', sessionId: 'id');
      expect(result.outcome, RideOutcome.failed);
      expect(result.message, contains('timed out'));
    });

    test('a socket error is a failure, not an exception', () async {
      final client = RideClient(
        httpClient: MockClient((_) async => throw const SocketException('no route')),
      );
      final result = await client.getSummary(baseUrl: 'https://s', apiToken: 't', sessionId: 'id');
      expect(result.outcome, RideOutcome.failed);
      expect(result.message, contains('network error'));
    });
  });

  test('the client never sends anything but GET', () async {
    final methods = <String>[];
    final client = RideClient(httpClient: MockClient((request) async {
      methods.add(request.method);
      return request.url.path == '/rides' ? jsonResponse(ridesBody, 200) : jsonResponse(summaryBody, 200);
    }));

    await client.listRides(baseUrl: 'https://s', apiToken: 't');
    await client.getSummary(baseUrl: 'https://s', apiToken: 't', sessionId: 'id');

    expect(methods, ['GET', 'GET']);
  });
}
