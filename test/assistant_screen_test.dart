import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/models/host.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/chat_client.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/ui/assistant/assistant_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

import 'support/memory_secrets.dart';

http.Response _json(int status, Object body,
        {Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json', ...headers});

Future<AppSettingsStore> _store(
  List<Host> hosts, {
  Map<String, String> tokens = const {},
  http.Client? probe,
}) async {
  SharedPreferences.setMockInitialValues({});
  HostResolver.invalidate();
  final secrets = MemorySecrets();
  final store = AppSettingsStore(secrets: secrets, probeClient: probe);
  await store.hosts.saveHosts(hosts);
  for (final e in tokens.entries) {
    await store.hosts.writeToken(e.key, e.value);
  }
  return store;
}

Future<void> _pump(
    WidgetTester tester, AppSettingsStore store, ChatClient client,
    {String? sessionId}) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: AssistantScreen(
        settingsStore: store, client: client, sessionId: sessionId),
  ));
  await tester.pump();
}

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byIcon(Icons.arrow_upward));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

const _host = Host(id: 'h1', name: 'Bike', baseUrl: 'https://bike.example.com');

void main() {
  testWidgets('empty state offers three example questions as chips',
      (tester) async {
    final store = await _store([_host], tokens: {'h1': 't'});
    await _pump(tester, store,
        ChatClient(httpClient: MockClient((_) async => _json(200, {}))));
    for (final q in assistantExampleQuestions) {
      expect(find.widgetWithText(ActionChip, q), findsOneWidget);
    }
    expect(assistantExampleQuestions, hasLength(3));
  });

  testWidgets(
      'tapping a chip sends it and renders the answer with badge and tool card',
      (tester) async {
    final store = await _store([_host], tokens: {'h1': 'tok'});
    late http.Request captured;
    final client = ChatClient(httpClient: MockClient((request) async {
      captured = request;
      return _json(200, {
        'answer': 'Son sürüşün 12.4 km idi.',
        'source': 'llm',
        'tool': {'name': 'get_ride_summary', 'arguments': {}},
        'result': {'distance_km': 12.4},
        'elapsed_ms': 5,
      });
    }));
    await _pump(tester, store, client);
    await tester
        .tap(find.widgetWithText(ActionChip, assistantExampleQuestions.first));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(captured.url.toString(), 'https://bike.example.com/chat');
    expect(captured.headers['Authorization'], 'Bearer tok');
    expect(
        jsonDecode(captured.body)['message'], assistantExampleQuestions.first);
    expect(find.text(assistantExampleQuestions.first),
        findsOneWidget); // user bubble
    expect(find.text('Son sürüşün 12.4 km idi.'), findsOneWidget);
    expect(find.text('Asistan'), findsWidgets);
    expect(find.text('LLM'), findsNothing);
    expect(find.textContaining('get_ride_summary', findRichText: true),
        findsOneWidget);
    expect(find.byType(ActionChip), findsNothing); // empty state gone
  });

  testWidgets('shows a progress indicator while waiting', (tester) async {
    final store = await _store([_host], tokens: {'h1': 'tok'});
    final client = ChatClient(
      httpClient: MockClient((_) => Future.delayed(
          const Duration(milliseconds: 300),
          () => _json(200, {'answer': 'ok', 'source': 'template'}))),
    );
    await _pump(tester, store, client);
    await _ask(tester, 'merhaba');
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('ok'), findsOneWidget);
  });

  testWidgets('sends the ride session id when opened from a ride',
      (tester) async {
    final store = await _store([_host], tokens: {'h1': 'tok'});
    late http.Request captured;
    final client = ChatClient(httpClient: MockClient((request) async {
      captured = request;
      return _json(200, {'answer': 'ok', 'source': 'template'});
    }));
    await _pump(tester, store, client, sessionId: '20260927-120000-ab12');
    expect(find.text('Ride 20260927-120000-ab12'), findsOneWidget);
    await _ask(tester, 'Bu sürüş nasıldı?');
    expect(jsonDecode(captured.body)['session_id'], '20260927-120000-ab12');
  });

  Future<void> expectFailure(
    WidgetTester tester,
    http.Response Function() response,
    String text,
  ) async {
    final store = await _store([_host], tokens: {'h1': 'tok'});
    await _pump(tester, store,
        ChatClient(httpClient: MockClient((_) async => response())));
    await _ask(tester, 'x');
    expect(find.textContaining(text), findsOneWidget);
  }

  testWidgets('401 points to the host settings', (tester) async {
    await expectFailure(tester, () => _json(401, {'detail': 'bad'}),
        'Check the token in Settings');
  });

  testWidgets('422 shows the validation message', (tester) async {
    await expectFailure(tester,
        () => _json(422, {'detail': 'message too short'}), 'message too short');
  });

  testWidgets('429 shows the Retry-After seconds', (tester) async {
    await expectFailure(
      tester,
      () => _json(429, {'detail': 'slow down'}, headers: {'retry-after': '12'}),
      'Rate limited. Try again in 12 s.',
    );
  });

  testWidgets('503 chat disabled says the assistant is disabled on this host',
      (tester) async {
    await expectFailure(tester, () => _json(503, {'detail': 'chat disabled'}),
        'disabled on "Bike"');
  });

  testWidgets('a network error says the host is unreachable', (tester) async {
    final store = await _store([_host], tokens: {'h1': 'tok'});
    await _pump(
      tester,
      store,
      ChatClient(
          httpClient:
              MockClient((_) async => throw const SocketException('no route'))),
    );
    await _ask(tester, 'x');
    expect(find.textContaining('Host unreachable'), findsOneWidget);
  });

  testWidgets(
      'no host configured explains where to add one, without any request',
      (tester) async {
    final store = await _store(const []);
    var requests = 0;
    await _pump(tester, store, ChatClient(httpClient: MockClient((_) async {
      requests++;
      return _json(200, {});
    })));
    await _ask(tester, 'x');
    expect(find.textContaining('Settings > Hosts'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('an unreachable cached host falls back to the next host once',
      (tester) async {
    final hosts = [
      const Host(id: 'a', name: 'Local', baseUrl: 'http://192.168.1.20:8000'),
      const Host(
          id: 'b', name: 'Remote', baseUrl: 'https://remote.example.com'),
    ];
    var localUp = true;
    final probe = MockClient((request) async {
      if (request.url.host == '192.168.1.20' && !localUp) {
        throw const SocketException('down');
      }
      return _json(200, {'status': 'ok'});
    });
    final store =
        await _store(hosts, tokens: {'a': 'ta', 'b': 'tb'}, probe: probe);
    final posted = <String>[];
    final client = ChatClient(httpClient: MockClient((request) async {
      posted.add(request.url.host);
      if (request.url.host == '192.168.1.20') {
        throw const SocketException('down');
      }
      return _json(200, {'answer': 'ok', 'source': 'template'});
    }));
    await _pump(tester, store, client);
    await store.load(); // caches the local host
    localUp = false;
    await _ask(tester, 'x');
    expect(posted, ['192.168.1.20', 'remote.example.com']);
    expect(find.text('ok'), findsOneWidget);
  });

  testWidgets('composer: 56 px circular send button, centred column of at most 720 px on a wide window',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = await _store([_host], tokens: {'h1': 't'});
    await _pump(tester, store, ChatClient(httpClient: MockClient((_) async => _json(200, {}))));

    final send = tester.getSize(find.widgetWithIcon(IconButton, Icons.arrow_upward));
    expect(send.width, greaterThanOrEqualTo(56));
    expect(send.height, greaterThanOrEqualTo(56));
    final composer = tester.getRect(find.byType(AssistantComposer));
    expect(composer.width, lessThanOrEqualTo(720));
    expect(composer.center.dx, closeTo(800, 1));
  });

  testWidgets('a pulsing placeholder card shows while waiting, no typing dots', (tester) async {
    final store = await _store([_host], tokens: {'h1': 'tok'});
    final client = ChatClient(
      httpClient: MockClient((_) => Future.delayed(
          const Duration(milliseconds: 300), () => _json(200, {'answer': 'ok', 'source': 'template'}))),
    );
    await _pump(tester, store, client);
    await _ask(tester, 'merhaba');
    expect(find.byType(PendingAnswerCard), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PendingAnswerCard), findsNothing);
  });

  testWidgets('the UI carries no brand or AI wording', (tester) async {
    final store = await _store([_host], tokens: {'h1': 'tok'});
    await _pump(tester, store, ChatClient(httpClient: MockClient((_) async => _json(200, {}))));
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' ').toLowerCase();
    for (final word in ['claude', 'anthropic', 'yapay zeka', ' ai ']) {
      expect(texts.contains(word), isFalse, reason: word);
    }
  });

  test('light theme follows the same tokens with its own contrast-safe palette', () {
    final dark = buildAppTheme();
    final light = buildAppTheme(brightness: Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.brightness, Brightness.light);
    expect(light.scaffoldBackgroundColor, isNot(dark.scaffoldBackgroundColor));
  });
}
