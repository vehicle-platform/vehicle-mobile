import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/models/host.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/services/host_store.dart';

import 'support/memory_secrets.dart';

void main() {
  setUp(HostResolver.invalidate);

  group('HostStore migration', () {
    test(
        'moves the old single URL and token into the first host, then removes the old keys',
        () async {
      SharedPreferences.setMockInitialValues(
          {'settings.server_base_url': 'http://192.168.1.20:8000'});
      final secrets = MemorySecrets()..values['settings.api_token'] = 'tok';
      final store = HostStore(secrets: secrets);

      final hosts = await store.load();
      expect(hosts, hasLength(1));
      expect(hosts.single.baseUrl, 'http://192.168.1.20:8000');
      expect(await store.readToken(hosts.single.id), 'tok');
      expect(secrets.values.keys, ['host.${hosts.single.id}.token']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.server_base_url'), isNull);
      expect(prefs.getString('hosts.v1'), isNot(contains('tok')));

      // Second start reads the stored list; nothing is migrated twice.
      expect(await store.load(), hosts);
    });

    test('a URL without a token migrates with no token', () async {
      SharedPreferences.setMockInitialValues(
          {'settings.server_base_url': 'https://s.example.com'});
      final store = HostStore(secrets: MemorySecrets());
      final host = (await store.load()).single;
      expect(await store.readToken(host.id), isNull);
    });

    test('no old settings and no hosts means an empty list', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await HostStore(secrets: MemorySecrets()).load(), isEmpty);
    });

    test('a corrupt stored list is an empty list, not an exception', () async {
      SharedPreferences.setMockInitialValues({'hosts.v1': '{not json'});
      expect(await HostStore(secrets: MemorySecrets()).load(), isEmpty);
    });
  });

  group('HostStore tokens', () {
    test(
        'each host has its own secure-storage key; deleting a host removes only its token',
        () async {
      SharedPreferences.setMockInitialValues({});
      final secrets = MemorySecrets();
      final store = HostStore(secrets: secrets);
      await store.saveHosts(const [
        Host(id: 'a', name: 'Local', baseUrl: 'http://10.0.0.5:8000'),
        Host(id: 'b', name: 'Remote', baseUrl: 'https://r.example.com'),
      ]);
      await store.writeToken('a', 'token-a');
      await store.writeToken('b', 'token-b');
      expect(secrets.values,
          {'host.a.token': 'token-a', 'host.b.token': 'token-b'});

      final prefs = await SharedPreferences.getInstance();
      expect(jsonEncode(prefs.getKeys().map(prefs.get).toList()),
          isNot(contains('token-')));

      await store.deleteHost('a');
      expect((await store.load()).map((h) => h.id), ['b']);
      expect(secrets.values, {'host.b.token': 'token-b'});
    });

    test('an empty token deletes the key', () async {
      SharedPreferences.setMockInitialValues({});
      final secrets = MemorySecrets()..values['host.a.token'] = 'x';
      await HostStore(secrets: secrets).writeToken('a', '  ');
      expect(secrets.values, isEmpty);
    });
  });

  group('web default host', () {
    test('an empty list offers the page origin as the first host', () async {
      SharedPreferences.setMockInitialValues({});
      final store = HostStore(
          secrets: MemorySecrets(), webOrigin: 'https://bike.example.com');
      final hosts = await store.load();
      expect(hosts.single.baseUrl, 'https://bike.example.com');
    });

    test('a configured list wins over the origin', () async {
      SharedPreferences.setMockInitialValues({});
      final store = HostStore(
          secrets: MemorySecrets(), webOrigin: 'https://bike.example.com');
      await store.saveHosts(const [
        Host(id: 'x', name: 'Other', baseUrl: 'https://other.example.com')
      ]);
      expect((await store.load()).single.baseUrl, 'https://other.example.com');
    });
  });

  group('HostResolver', () {
    const local =
        Host(id: 'local', name: 'Local', baseUrl: 'http://192.168.1.20:8000');
    const remote = Host(
        id: 'remote', name: 'Remote', baseUrl: 'https://remote.example.com/');

    Future<(HostStore, MemorySecrets)> store(List<Host> hosts) async {
      SharedPreferences.setMockInitialValues({});
      final secrets = MemorySecrets();
      final s = HostStore(secrets: secrets);
      await s.saveHosts(hosts);
      for (final h in hosts) {
        await s.writeToken(h.id, 'token-${h.id}');
      }
      return (s, secrets);
    }

    test(
        'probes in list order and uses the first reachable host, with its own token',
        () async {
      final (s, _) = await store([local, remote]);
      final probed = <String>[];
      final resolver = HostResolver(s, client: MockClient((request) async {
        probed.add(request.url.toString());
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('{"status":"ok"}', 200);
      }));
      final active = (await resolver.resolve())!;
      expect(active.host.id, 'local');
      expect(active.token, 'token-local');
      expect(probed, ['http://192.168.1.20:8000/health']);
    });

    test(
        'falls back to the next host when the first is down, and caches the choice',
        () async {
      final (s, _) = await store([local, remote]);
      final probed = <String>[];
      final resolver = HostResolver(s, client: MockClient((request) async {
        probed.add(request.url.toString());
        if (request.url.host == '192.168.1.20') {
          throw const SocketException('down');
        }
        return http.Response('{"status":"ok"}', 200);
      }));
      expect((await resolver.resolve())!.host.id, 'remote');
      expect(probed, [
        'http://192.168.1.20:8000/health',
        'https://remote.example.com/health'
      ]);

      probed.clear();
      expect((await resolver.resolve())!.host.id, 'remote');
      expect(probed, isEmpty, reason: 'cached');

      expect((await resolver.resolve(forceProbe: true))!.host.id, 'remote');
      expect(probed, hasLength(2), reason: 're-probes in list order');
    });

    test('a non-2xx or slow health answer counts as unreachable', () async {
      final (s, _) = await store([local, remote]);
      final resolver = HostResolver(
        s,
        timeout: const Duration(milliseconds: 20),
        client: MockClient((request) async {
          if (request.url.host == '192.168.1.20') {
            return Future.delayed(const Duration(milliseconds: 200),
                () => http.Response('ok', 200));
          }
          return http.Response('{}', 200);
        }),
      );
      expect((await resolver.resolve())!.host.id, 'remote');

      HostResolver.invalidate();
      final failing = HostResolver(s,
          client: MockClient((_) async => http.Response('nope', 503)));
      expect((await failing.resolve())!.host.id, 'local',
          reason: 'none reachable: first host');
    });

    test('a single host is used without probing; no host is null', () async {
      final (s, _) = await store([remote]);
      final resolver = HostResolver(s,
          client:
              MockClient((_) async => throw StateError('no probe expected')));
      expect((await resolver.resolve())!.host.id, 'remote');

      SharedPreferences.setMockInitialValues({});
      expect(await HostResolver(HostStore(secrets: MemorySecrets())).resolve(),
          isNull);
    });

    test('editing the list invalidates the cached choice', () async {
      final (s, _) = await store([local, remote]);
      var localUp = true;
      final resolver = HostResolver(s, client: MockClient((request) async {
        if (request.url.host == '192.168.1.20' && !localUp) {
          throw const SocketException('down');
        }
        return http.Response('{}', 200);
      }));
      expect((await resolver.resolve())!.host.id, 'local');
      localUp = false;
      expect((await resolver.resolve())!.host.id, 'local', reason: 'cached');
      await s.saveHosts([remote, local]); // reordered
      expect((await resolver.resolve())!.host.id, 'remote');
    });
  });

  test(
      'AppSettingsStore load follows the active host (URL and token of the same host)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secrets = MemorySecrets();
    final probe = MockClient((request) async {
      if (request.url.host == '192.168.1.20') {
        throw const SocketException('down');
      }
      return http.Response('{}', 200);
    });
    final store = AppSettingsStore(secrets: secrets, probeClient: probe);
    await store.hosts.saveHosts(const [
      Host(id: 'a', name: 'Local', baseUrl: 'http://192.168.1.20:8000'),
      Host(id: 'b', name: 'Remote', baseUrl: 'https://remote.example.com'),
    ]);
    await store.hosts.writeToken('a', 'ta');
    await store.hosts.writeToken('b', 'tb');
    final settings = await store.load();
    expect(settings.serverBaseUrl, 'https://remote.example.com');
    expect(settings.apiToken, 'tb');
    expect(settings.hostName, 'Remote');
  });
}
