import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vehicle_mobile/models/app_notification.dart';
import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:vehicle_mobile/services/notifications_client.dart';

const _base = 'https://vehicle.example.test';

Map<String, Object?> note(int id,
        {String severity = 'info',
        String kind = 'ride_summary',
        bool read = false,
        String? session}) =>
    {
      'id': id,
      'vehicle_id': 'veh-1',
      'kind': kind,
      'severity': severity,
      'title': 'Title $id',
      'body': 'Body $id',
      'session_id': session,
      'fault_id': null,
      'created_utc': '2026-11-25T10:00:00Z',
      'read': read,
    };

http.Response body(List<Map<String, Object?>> items, {int? latest}) =>
    http.Response(
        jsonEncode({
          'notifications': items,
          'latest_id': latest ?? (items.isEmpty ? 0 : items.last['id']),
        }),
        200,
        headers: {'content-type': 'application/json'});

void main() {
  test('list 200 parses entries and sends since_id, limit and bearer',
      () async {
    late http.Request seen;
    final client = NotificationsClient(httpClient: MockClient((r) async {
      seen = r;
      return body(
          [note(5, severity: 'critical', kind: 'fault', session: 's1')]);
    }));
    final r = await client.list(
        baseUrl: '$_base/', token: 'tok', sinceId: 4, limit: 50);
    expect(r.outcome, NotificationsOutcome.ok);
    expect(r.items.single.severity, NotificationSeverity.critical);
    expect(r.items.single.kind, NotificationKind.fault);
    expect(r.items.single.sessionId, 's1');
    expect(r.latestId, 5);
    expect(seen.url.toString(), '$_base/notifications?since_id=4&limit=50');
    expect(seen.headers['Authorization'], 'Bearer tok');
  });

  test('limit is clamped to 1..100', () async {
    final urls = <String>[];
    final client = NotificationsClient(httpClient: MockClient((r) async {
      urls.add(r.url.query);
      return body([]);
    }));
    await client.list(baseUrl: _base, token: 't', limit: 500);
    await client.list(baseUrl: _base, token: 't', limit: 0);
    expect(urls, ['since_id=0&limit=100', 'since_id=0&limit=1']);
  });

  test('a bad row is skipped, unknown kind and severity degrade', () async {
    final client = NotificationsClient(
        httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'notifications': [
                {'id': 'x', 'title': 't'},
                {...note(2), 'kind': 'weird', 'severity': 'loud'},
              ],
              'latest_id': 2
            }),
            200)));
    final r = await client.list(baseUrl: _base, token: 't');
    expect(r.items.length, 1);
    expect(r.items.single.kind, NotificationKind.outlook);
    expect(r.items.single.severity, NotificationSeverity.info);
  });

  test('401 reports the session end', () async {
    final events = <AuthEvent>[];
    final sub = AuthEvents.stream.listen(events.add);
    final r = await NotificationsClient(
            httpClient: MockClient((_) async => http.Response('{}', 401)))
        .list(baseUrl: _base, token: 't');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(r.outcome, NotificationsOutcome.unauthorized);
    expect(events, contains(AuthEvent.unauthorized));
  });

  test('404 means not supported', () async {
    final r = await NotificationsClient(
            httpClient:
                MockClient((_) async => http.Response('Not Found', 404)))
        .list(baseUrl: _base, token: 't');
    expect(r.outcome, NotificationsOutcome.notSupported);
  });

  test('429 carries Retry-After; 500 fails; network is unreachable', () async {
    final slow = await NotificationsClient(
            httpClient: MockClient((_) async =>
                http.Response('', 429, headers: {'retry-after': '12'})))
        .list(baseUrl: _base, token: 't');
    expect(slow.outcome, NotificationsOutcome.rateLimited);
    expect(slow.retryAfterSeconds, 12);
    final bad = await NotificationsClient(
            httpClient: MockClient((_) async => http.Response('', 500)))
        .list(baseUrl: _base, token: 't');
    expect(bad.outcome, NotificationsOutcome.failed);
    final down = await NotificationsClient(
            httpClient:
                MockClient((_) async => throw http.ClientException('x')))
        .list(baseUrl: _base, token: 't');
    expect(down.outcome, NotificationsOutcome.unreachable);
    final hung = await NotificationsClient(
      httpClient: MockClient((_) => Completer<http.Response>().future),
      totalTimeout: const Duration(milliseconds: 10),
    ).list(baseUrl: _base, token: 't');
    expect(hung.outcome, NotificationsOutcome.unreachable);
  });

  test('markRead and markAllRead POST and accept 204', () async {
    final seen = <String>[];
    final client = NotificationsClient(httpClient: MockClient((r) async {
      seen.add('${r.method} ${r.url.path}');
      return http.Response('', 204);
    }));
    expect((await client.markRead(baseUrl: _base, token: 't', id: 7)).isSuccess,
        isTrue);
    expect((await client.markAllRead(baseUrl: _base, token: 't')).isSuccess,
        isTrue);
    expect(
        seen, ['POST /notifications/7/read', 'POST /notifications/read-all']);
  });

  test('plain http to a public host is refused', () async {
    var called = false;
    final r = await NotificationsClient(httpClient: MockClient((_) async {
      called = true;
      return body([]);
    })).list(baseUrl: 'http://example.com', token: 't');
    expect(r.outcome, NotificationsOutcome.failed);
    expect(called, isFalse);
  });
}
