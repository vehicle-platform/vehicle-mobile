import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/notifications/notification_center.dart';
import 'package:vehicle_mobile/services/notifications/notification_store.dart';
import 'package:vehicle_mobile/services/notifications/notification_sync.dart';
import 'package:vehicle_mobile/services/notifications_client.dart';
import 'package:vehicle_mobile/services/voice/critical_announcer.dart';

import 'notifications_client_test.dart' show note;
import 'support/signed_in.dart';

/// Serves a growing inbox honouring since_id / limit like the server.
class FakeServer {
  final List<Map<String, Object?>> all = [];
  final List<int> sinceIds = [];
  int status = 200;

  MockClient get client => MockClient((req) async {
        if (status != 200) return http.Response('x', status);
        if (req.method == 'POST') return http.Response('', 204);
        final since = int.parse(req.url.queryParameters['since_id']!);
        final limit = int.parse(req.url.queryParameters['limit']!);
        sinceIds.add(since);
        final items = [
          for (final n in all)
            if ((n['id'] as int) > since) n
        ].take(limit).toList();
        return http.Response(
            jsonEncode({
              'notifications': items,
              'latest_id': all.isEmpty ? 0 : all.last['id']
            }),
            200);
      });
}

NotificationSync _sync(FakeServer server, AppSettingsStore store,
        {int pageLimit = 100}) =>
    NotificationSync(
      settingsStore: store,
      client: NotificationsClient(httpClient: server.client),
      pageLimit: pageLimit,
    );

void main() {
  late AppSettingsStore store;
  late FakeServer server;

  setUp(() {
    store = signedInStore();
    server = FakeServer();
  });

  test('first pull asks since_id=0, the next one the highest id seen',
      () async {
    server.all.addAll([note(1), note(2)]);
    final sync = _sync(server, store);
    final first = await sync.pull();
    expect(first.state, SyncState.ok);
    expect(first.fresh.map((n) => n.id), [1, 2]);
    expect(await const NotificationStore().lastSeenId('h1'), 2);

    server.all.add(note(3));
    final second = await sync.pull();
    expect(second.fresh.map((n) => n.id), [3]);
    expect(server.sinceIds, [0, 2]);
  });

  test('nothing new means nothing fresh (dedupe)', () async {
    server.all.add(note(1));
    final sync = _sync(server, store);
    await sync.pull();
    final again = await sync.pull();
    expect(again.fresh, isEmpty);
    expect(again.fetched, isEmpty);
  });

  test('a full pull rebuilds the inbox but only newer ids are fresh', () async {
    server.all.addAll([note(1), note(2), note(3)]);
    final sync = _sync(server, store);
    await sync.pull();
    server.all.add(note(4));
    final full = await sync.pull(full: true);
    expect(full.fetched.map((n) => n.id), [1, 2, 3, 4]);
    expect(full.fresh.map((n) => n.id), [4]);
  });

  test('pages through the answer when the limit is reached', () async {
    server.all.addAll([for (var i = 1; i <= 5; i++) note(i)]);
    final r = await _sync(server, store, pageLimit: 2).pull();
    expect(r.fetched.map((n) => n.id), [1, 2, 3, 4, 5]);
    expect(server.sinceIds, [0, 2, 4]);
    expect(await const NotificationStore().lastSeenId('h1'), 5);
  });

  test('the stored id never moves backwards', () async {
    const s = NotificationStore();
    await s.saveLastSeenId('h1', 9);
    await s.saveLastSeenId('h1', 4);
    expect(await s.lastSeenId('h1'), 9);
  });

  test('last seen id is kept per host', () async {
    const s = NotificationStore();
    await s.saveLastSeenId('a', 3);
    expect(await s.lastSeenId('b'), 0);
  });

  test('404 -> notSupported, 401 -> unauthorized, 500 -> failed', () async {
    final sync = _sync(server, store);
    server.status = 404;
    expect((await sync.pull()).state, SyncState.notSupported);
    server.status = 401;
    expect((await sync.pull()).state, SyncState.unauthorized);
    server.status = 500;
    expect((await sync.pull()).state, SyncState.failed);
  });

  test('without a session nothing is requested', () async {
    SharedPreferences.setMockInitialValues({});
    final r =
        await _sync(server, const AppSettingsStore(secrets: _Empty())).pull();
    expect(r.state, SyncState.noSession);
    expect(server.sinceIds, isEmpty);
  });

  group('NotificationCenter', () {
    final spoken = <String>[];
    NotificationCenter center({bool announce = true}) {
      spoken.clear();
      return NotificationCenter(
        sync: _sync(server, store),
        announcer: announce
            ? CriticalAnnouncer(speak: (s) async => spoken.add(s))
            : null,
      );
    }

    test('badge counts unread entries and drops on read', () async {
      server.all.addAll([note(1), note(2, read: true), note(3)]);
      final c = center();
      await c.refresh();
      expect(c.unreadCount, 2);
      expect(c.items.map((n) => n.id), [3, 2, 1]);
      await c.markRead(1);
      expect(c.unreadCount, 1);
      await c.markAllRead();
      expect(c.unreadCount, 0);
      c.dispose();
    });

    test('a critical notification is announced once, not on later pulls',
        () async {
      server.all.add(note(1, severity: 'critical'));
      final c = center();
      await c.refresh();
      expect(spoken.length, 1);
      expect(spoken.single, contains('Title 1'));
      await c.refresh();
      await c.refresh(full: true);
      expect(spoken.length, 1);
      c.dispose();
    });

    test('a critical entry already seen before startup is not announced again',
        () async {
      server.all.add(note(1, severity: 'critical'));
      await const NotificationStore().saveLastSeenId('h1', 1);
      final c = center();
      await c.refresh();
      expect(spoken, isEmpty);
      expect(c.items.length, 1);
      c.dispose();
    });

    test('info and warning entries are never announced', () async {
      server.all.addAll([note(1), note(2, severity: 'warning')]);
      final c = center();
      await c.refresh();
      expect(spoken, isEmpty);
      c.dispose();
    });

    test('404 hides the feature, a resume tries again', () async {
      server.status = 404;
      final c = center();
      await c.refresh();
      expect(c.available, isFalse);
      server.status = 200;
      server.all.add(note(1));
      c.resumed();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.available, isTrue);
      expect(c.unreadCount, 1);
      c.dispose();
    });
  });
}

class _Empty implements SecretStore {
  const _Empty();
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}
