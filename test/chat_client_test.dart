import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vehicle_mobile/models/chat_message.dart';
import 'package:vehicle_mobile/services/chat_client.dart';

http.Response _json(int status, Object body,
        {Map<String, String> headers = const {}}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...headers},
    );

Map<String, Object?> _answer(
        {String source = 'llm', Object? tool, Object? result}) =>
    {
      'answer': 'Your last ride was 12.4 km.',
      'source': source,
      'tool': tool,
      'result': result,
      'elapsed_ms': 812,
    };

ChatClient _client(http.Response Function(http.Request) handler) =>
    ChatClient(httpClient: MockClient((request) async => handler(request)));

void main() {
  test('posts message, session_id and locale with the bearer token', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json(200, _answer());
    });
    final result = await client.send(
      baseUrl: 'https://vehicle.example.com/',
      apiToken: 'secret-token',
      message: 'How was my last ride?',
      sessionId: 'abc',
    );
    expect(result.isSuccess, isTrue);
    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'https://vehicle.example.com/chat');
    expect(captured.headers['Authorization'], 'Bearer secret-token');
    expect(jsonDecode(captured.body), {
      'message': 'How was my last ride?',
      'session_id': 'abc',
      'locale': 'tr'
    });
  });

  test('a missing session id is sent as null', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json(200, _answer());
    });
    await client.send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(jsonDecode(captured.body)['session_id'], isNull);
  });

  test(
      'parses the answer, source, tool, result and elapsed time (UTF-8 intact)',
      () async {
    final client = _client((_) => _json(
        200,
        _answer(
          source: 'template',
          tool: {
            'name': 'get_ride_summary',
            'arguments': {'session_id': 'abc'},
          },
          result: {'distance_km': 12.4},
        )));
    final result =
        await client.send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    final answer = result.answer!;
    expect(answer.answer, 'Your last ride was 12.4 km.');
    expect(answer.source, ChatSource.template);
    expect(answer.tool!.name, 'get_ride_summary');
    expect(answer.tool!.arguments, {'session_id': 'abc'});
    expect(answer.result, {'distance_km': 12.4});
    expect(answer.elapsedMs, 812);
  });

  test('a null tool stays null', () async {
    final client = _client((_) => _json(200, _answer(source: 'unsupported')));
    final answer =
        (await client.send(baseUrl: 'https://s', apiToken: 't', message: 'x'))
            .answer!;
    expect(answer.tool, isNull);
    expect(answer.source, ChatSource.unsupported);
  });

  test('401 is a token problem', () async {
    final client = _client((_) => _json(401, {'detail': 'invalid token'}));
    final result =
        await client.send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.outcome, ChatOutcome.unauthorized);
  });

  test('422 carries the validation message (string and FastAPI list forms)',
      () async {
    var result =
        await _client((_) => _json(422, {'detail': 'message too long'}))
            .send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.outcome, ChatOutcome.invalid);
    expect(result.message, 'message too long');

    result = await _client((_) => _json(422, {
          'detail': [
            {
              'msg': 'String should have at most 500 characters',
              'loc': ['body', 'message']
            },
          ],
        })).send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.message, 'String should have at most 500 characters');
  });

  test(
      '429 parses Retry-After seconds, and tolerates a missing or non-numeric header',
      () async {
    var result = await _client((_) => _json(429, {'detail': 'rate limited'},
            headers: {'retry-after': '17'}))
        .send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.outcome, ChatOutcome.rateLimited);
    expect(result.retryAfterSeconds, 17);

    result = await _client((_) => _json(429, {'detail': 'rate limited'}))
        .send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.outcome, ChatOutcome.rateLimited);
    expect(result.retryAfterSeconds, isNull);

    result = await _client((_) => _json(429, {},
            headers: {'retry-after': 'Wed, 21 Oct 2026 07:28:00 GMT'}))
        .send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.retryAfterSeconds, isNull);
  });

  test('503 chat disabled is "disabled"; another 503 is a failure', () async {
    var result = await _client((_) => _json(503, {'detail': 'chat disabled'}))
        .send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.outcome, ChatOutcome.disabled);

    result =
        await _client((_) => _json(503, {'detail': 'no api token configured'}))
            .send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.outcome, ChatOutcome.failed);
    expect(result.message, 'no api token configured');
  });

  test('a network error is "unreachable", also a timeout', () async {
    var result = await ChatClient(
            httpClient: MockClient(
                (_) async => throw const SocketException('no route')))
        .send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.outcome, ChatOutcome.unreachable);

    result = await ChatClient(
            httpClient:
                MockClient((_) async => throw http.ClientException('refused')))
        .send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.outcome, ChatOutcome.unreachable);

    result = await ChatClient(
      httpClient: MockClient((_) => Future.delayed(
          const Duration(seconds: 1), () => _json(200, _answer()))),
      totalTimeout: const Duration(milliseconds: 20),
    ).send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.outcome, ChatOutcome.unreachable);
  });

  test('a malformed 200 body is a failure, not an exception', () async {
    final result = await _client((_) => http.Response('[]', 200))
        .send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.outcome, ChatOutcome.failed);
  });

  test('another status is a failure with the server detail', () async {
    final result = await _client((_) => _json(500, {'detail': 'boom'}))
        .send(baseUrl: 'https://s', apiToken: 't', message: 'x');
    expect(result.outcome, ChatOutcome.failed);
    expect(result.statusCode, 500);
    expect(result.message, 'boom');
  });

  test('the token is never sent over plain http to a public host', () async {
    var requests = 0;
    final client = _client((_) {
      requests++;
      return _json(200, _answer());
    });
    final result = await client.send(
        baseUrl: 'http://203.0.113.9:8000', apiToken: 'secret', message: 'x');
    expect(result.outcome, ChatOutcome.failed);
    expect(result.message, contains('plain http://'));
    expect(requests, 0);
  });
}
