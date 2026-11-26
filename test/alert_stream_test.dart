import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vehicle_mobile/models/live_alert.dart';
import 'package:vehicle_mobile/services/alerts/alert_controller.dart';
import 'package:vehicle_mobile/services/alerts/alert_http.dart';
import 'package:vehicle_mobile/services/alerts/alert_prefs.dart';
import 'package:vehicle_mobile/services/alerts/sse.dart';
import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/signed_in.dart';

String _event(String name, Map<String, Object?> data) =>
    'event: $name\ndata: ${jsonEncode(data)}\n\n';

Map<String, Object?> _alert({
  String event = 'alert',
  String rule = 'ALR-001',
  String cls = 'P1',
  bool speak = true,
  int? id = 7,
  String? reason,
}) =>
    {
      'event': event,
      'id': id,
      'rule_id': rule,
      'class': cls,
      'severity': cls == 'P1' ? 'critical' : 'warning',
      'text': 'Coolant temperature high',
      'detail': 'Coolant 112 degC',
      'value': 112.0,
      'unit': 'degC',
      'device_id': 'bike-1',
      'ts': '2026-11-26T09:00:00.000Z',
      'speak': speak,
      'reason': reason,
    };

/// A scripted server: each `open` hands out the next controller.
class FakeServer {
  final List<StreamController<List<int>>> streams = [];
  final List<Uri> urls = [];
  final List<Map<String, String>> headers = [];
  Object? failWith;

  Future<Stream<List<int>>> open(Uri url, Map<String, String> h) async {
    urls.add(url);
    headers.add(h);
    final f = failWith;
    if (f != null) throw f;
    final c = StreamController<List<int>>();
    streams.add(c);
    return c.stream;
  }

  void send(String text, {int stream = -1}) =>
      streams[stream < 0 ? streams.length - 1 : stream].add(utf8.encode(text));
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('SSE parser', () {
    test('events, heartbeat comments, CRLF and split chunks', () async {
      const raw = ': heartbeat\r\n\r\nevent: alert\r\ndata: {"a":1}\r\n\r\n'
          'event: clear\ndata: {"b":2}\n\n';
      final bytes = utf8.encode(raw);
      const cut = 23;
      final events = await parseSse(Stream.fromIterable(
              [bytes.sublist(0, cut), bytes.sublist(cut)]))
          .toList();
      expect([for (final e in events) (e.event, e.data)],
          [('alert', '{"a":1}'), ('clear', '{"b":2}')]);
    });

    test('a multi-byte character split across chunks survives', () async {
      final bytes = utf8.encode('event: alert\ndata: °C\n\n');
      final events = await parseSse(Stream.fromIterable(
              [bytes.sublist(0, 20), bytes.sublist(20)]))
          .toList();
      expect(events.single.data, '°C');
    });
  });

  group('LiveAlert', () {
    test('parses an alert and a clear; ignores malformed payloads', () {
      final a = LiveAlert.tryParse('alert', _alert())!;
      expect(a.alertClass, LiveAlertClass.p1);
      expect(a.value, 112.0);
      expect(a.speak, isTrue);
      expect(a.key, 'bike-1|ALR-001');
      final c = LiveAlert.tryParse('clear', _alert(event: 'clear', reason: 'recovered'))!;
      expect(c.isClear, isTrue);
      expect(c.reason, 'recovered');
      expect(LiveAlert.tryParse('alert', {'rule_id': 'x'}), isNull);
      expect(LiveAlert.tryParse('alert', 'nope'), isNull);
      expect(LiveAlert.tryParse('alert', _alert(cls: 'P3')), isNull);
    });
  });

  group('AlertController', () {
    late FakeServer server;
    late List<String> spoken;
    var reconnects = 0;

    AlertController make({
      Duration p1 = const Duration(seconds: 30),
      Duration p2 = const Duration(seconds: 12),
      String? Function()? locale,
    }) {
      reconnects = 0;
      return AlertController(
        settingsStore: signedInStore(),
        opener: server.open,
        onReconnect: () async => reconnects++,
        onSpeak: (a) async => spoken.add(a.text),
        locale: locale,
        backoff: (_) => const Duration(milliseconds: 5),
        p1Display: p1,
        p2Display: p2,
      );
    }

    setUp(() {
      server = FakeServer();
      spoken = [];
    });

    test('connects with the bearer header, shows the alert, hides it on clear',
        () async {
      final c = make();
      addTearDown(c.dispose);
      c.start();
      await _settle();
      expect(server.urls.single.toString(),
          'https://vehicle.example.test/alerts/stream?locale=en');
      expect(server.headers.single['Authorization'], 'Bearer tok');
      expect(c.connected, isTrue);
      expect(reconnects, 1);

      server.send(': heartbeat\n\n');
      server.send(_event('alert', _alert()));
      await _settle();
      expect(c.banner?.text, 'Coolant temperature high');
      expect(c.banner?.alertClass, LiveAlertClass.p1);
      expect(spoken, ['Coolant temperature high']);

      server.send(_event('clear', _alert(event: 'clear', reason: 'recovered')));
      await _settle();
      expect(c.banner, isNull);
    });

    test('requests the UI locale, unsupported codes fall back to en, and a '
        'change applies on the next reconnect', () async {
      var code = 'tr';
      final c = make(locale: () => code);
      addTearDown(c.dispose);
      c.start();
      await _settle();
      expect(server.urls.last.queryParameters['locale'], 'tr');
      code = 'de';
      await server.streams.last.close();
      await _settle();
      expect(server.urls.length, greaterThan(1));
      expect(server.urls.last.queryParameters['locale'], 'en');
    });

    test('P1 wins over P2; the banner hides after its display time', () async {
      final c = make(p1: const Duration(milliseconds: 60), p2: const Duration(milliseconds: 30));
      addTearDown(c.dispose);
      c.start();
      await _settle();
      server.send(_event('alert', _alert(rule: 'ALR-002', cls: 'P2', speak: false, id: 8)));
      await _settle();
      expect(c.banner?.alertClass, LiveAlertClass.p2);
      server.send(_event('alert', _alert()));
      await _settle();
      expect(c.banner?.alertClass, LiveAlertClass.p1);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(c.banner, isNull);
      expect(spoken, hasLength(1));
    });

    test('a muted P1 type is silent but still shows its banner; a muted P2 type shows nothing',
        () async {
      final c = make();
      addTearDown(c.dispose);
      c.start();
      await _settle();
      server.send(_event('alert', _alert()));
      await _settle();
      expect(spoken, hasLength(1));
      server.send(_event('clear', _alert(event: 'clear')));
      await _settle();

      await const AlertPrefs().setMuted('ALR-001', true);
      server.send(_event('alert', _alert(id: 9)));
      await _settle();
      expect(spoken, hasLength(1), reason: 'voice muted');
      expect(c.banner, isNotNull, reason: 'a P1 banner is never muted');

      server.send(_event('alert', _alert(rule: 'ALR-002', cls: 'P2', speak: false, id: 10)));
      await _settle();
      await const AlertPrefs().setMuted('ALR-002', true);
      server.send(_event('clear', _alert(event: 'clear', rule: 'ALR-002', cls: 'P2')));
      server.send(_event('clear', _alert(event: 'clear')));
      await _settle();
      expect(c.banner, isNull);
      server.send(_event('alert', _alert(rule: 'ALR-002', cls: 'P2', speak: false, id: 11)));
      await _settle();
      expect(c.banner, isNull, reason: 'muted P2 is not shown live');
    });

    test('reconnects with backoff and pulls the inbox again (no replay)',
        () async {
      final c = make();
      addTearDown(c.dispose);
      c.start();
      await _settle();
      expect(server.streams, hasLength(1));
      await server.streams.first.close();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(server.streams.length, greaterThanOrEqualTo(2));
      expect(reconnects, greaterThanOrEqualTo(2));
      expect(alertBackoff(0), const Duration(seconds: 1));
      expect(alertBackoff(99), const Duration(seconds: 30));
    });

    test('a 401 reports the ended session and stops; a 404 stops quietly',
        () async {
      final events = <AuthEvent>[];
      final sub = AuthEvents.stream.listen(events.add);
      addTearDown(sub.cancel);
      final c = make();
      addTearDown(c.dispose);
      server.failWith = const AlertHttpException(401);
      c.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events, [AuthEvent.unauthorized]);
      expect(server.urls, hasLength(1));

      final c2 = make();
      addTearDown(c2.dispose);
      server.failWith = const AlertHttpException(404);
      c2.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(server.urls, hasLength(2));
    });

    test('stop closes the stream and start reopens it', () async {
      final c = make();
      addTearDown(c.dispose);
      c.start();
      await _settle();
      c.stop();
      await _settle();
      expect(c.connected, isFalse);
      c.start();
      await _settle();
      expect(server.streams, hasLength(2));
      expect(c.connected, isTrue);
    });

    test('the alert types are remembered for Settings', () async {
      final c = make();
      addTearDown(c.dispose);
      c.start();
      await _settle();
      server.send(_event('alert', _alert()));
      await _settle();
      final types = await const AlertPrefs().load();
      expect(types['ALR-001']!.text, 'Coolant temperature high');
      expect(types['ALR-001']!.alertClass, LiveAlertClass.p1);
      expect(types['ALR-001']!.muted, isFalse);
      SharedPreferences.setMockInitialValues({});
    });
  });
}
