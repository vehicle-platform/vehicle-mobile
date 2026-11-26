import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/services/assistant_provider_client.dart';
import 'package:vehicle_mobile/services/chat_client.dart';
import 'package:vehicle_mobile/services/conversations_client.dart';
import 'package:vehicle_mobile/services/voice/intercom_audio.dart';
import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/ui/assistant/assistant_screen.dart';
import 'package:vehicle_mobile/ui/assistant/conversation_list.dart';
import 'package:vehicle_mobile/ui/settings/assistant_memory_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

import 'support/fake_voice.dart';
import 'support/signed_in.dart';

Widget _app(Widget child) => MaterialApp(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

VoiceController _voice() => VoiceController(
      recognizer: FakeRecognizer(),
      output: FakeOutput()..instant = true,
      intercom: IntercomAudio(supported: false),
    );

Map<String, Object?> _conv(String id, String title) => {
      'id': id,
      'title': title,
      'created': '2026-11-26T10:00:00Z',
      'updated': '2026-11-26T10:05:00Z',
      'mode': 'data',
    };

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

/// A fake vehicle-server for the conversation flows; every route can be
/// replaced per test.
class _Server {
  final chatBodies = <Map<String, Object?>>[];
  int listCalls = 0;
  int deleteCalls = 0;
  List<Map<String, Object?>> convs = [_conv('c1', 'Morning ride')];
  FutureOr<http.Response> Function(http.Request)? onList;
  FutureOr<http.Response> Function(http.Request)? onChat;
  FutureOr<http.Response> Function(http.Request)? onSearch;
  FutureOr<http.Response> Function(http.Request)? onPatch;
  FutureOr<http.Response> Function(http.Request)? onDelete;

  MockClient get client => MockClient((req) async {
        final path = req.url.path;
        if (req.method == 'GET' && path == '/conversations') {
          listCalls++;
          return onList != null
              ? onList!(req)
              : _json({'conversations': convs, 'next_before': null});
        }
        if (req.method == 'GET' && path == '/conversations/search') {
          return onSearch != null ? onSearch!(req) : _json({'hits': []});
        }
        if (req.method == 'GET' && path.startsWith('/conversations/')) {
          final id = path.split('/').last;
          return _json({
            'conversation': convs.firstWhere((c) => c['id'] == id),
            'messages': [
              {
                'id': 1,
                'role': 'user',
                'text': 'Stored question',
                'created': '2026-11-26T10:00:00Z',
              },
              {
                'id': 2,
                'role': 'assistant',
                'text': 'Stored answer.',
                'source': 'template',
                'created': '2026-11-26T10:00:02Z',
              },
            ],
          });
        }
        if (req.method == 'PATCH') {
          return onPatch != null ? onPatch!(req) : http.Response('boom', 500);
        }
        if (req.method == 'DELETE' && path.startsWith('/conversations/')) {
          deleteCalls++;
          return onDelete != null ? onDelete!(req) : http.Response('', 204);
        }
        if (req.method == 'POST' && path == '/chat') {
          chatBodies.add(jsonDecode(req.body) as Map<String, Object?>);
          if (onChat != null) return onChat!(req);
          return _json({
            'answer': 'Fine answer.',
            'source': 'template',
            'conversation_id': 'new-id',
            'chips': <String>[],
          });
        }
        return http.Response('not found', 404);
      });

  Widget screen() {
    final mock = client;
    return _app(AssistantScreen(
      settingsStore: signedInStore(),
      client: ChatClient(httpClient: mock),
      providerClient: AssistantProviderClient(httpClient: mock),
      conversationsClient: ConversationsClient(httpClient: mock),
      voice: _voice(),
    ));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
}

Future<void> _openMenu(WidgetTester tester, String id, String item) async {
  await tester.tap(find.byKey(ValueKey('conv-menu-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'temporary mode: switching OFF starts a new chat, a returned conversation_id is ignored and the list is not refreshed',
      (tester) async {
    _wide(tester);
    final server = _Server()
      ..onChat = (_) => _json({
            'answer': 'Temp answer.',
            'source': 'template',
            'conversation_id': 'leaked-id',
            'chips': <String>[],
          });
    await tester.pumpWidget(server.screen());
    await tester.pumpAndSettle();
    expect(server.listCalls, 1);

    await tester.tap(find.byKey(const ValueKey('temporary-chat-toggle')));
    await tester.pumpAndSettle();
    await _type(tester, 'temporary question');
    await tester.pumpAndSettle();
    expect(find.text('Temp answer.'), findsOneWidget);
    expect(server.chatBodies.last['temporary'], isTrue);
    expect(server.chatBodies.last['conversation_id'], isNull);
    expect(server.listCalls, 1, reason: 'a temporary chat is not stored');

    // Switching OFF must not carry the temporary transcript into storage.
    await tester.tap(find.byKey(const ValueKey('temporary-chat-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Temp answer.'), findsNothing);
    expect(find.text('temporary question'), findsNothing);
    expect(find.byKey(const ValueKey('temporary-chat-banner')), findsNothing);

    server.onChat = null;
    await _type(tester, 'stored question');
    await tester.pumpAndSettle();
    expect(server.chatBodies.last['temporary'], isNull);
    expect(server.chatBodies.last['conversation_id'], isNull,
        reason: 'the ignored temporary id must not be continued');
  });

  testWidgets(
      'a late reply after switching chats is dropped and does not overwrite the open conversation',
      (tester) async {
    _wide(tester);
    final server = _Server();
    final late = Completer<http.Response>();
    server.onChat = (_) => late.future;
    await tester.pumpWidget(server.screen());
    await tester.pumpAndSettle();

    await _type(tester, 'slow question');
    expect(find.text('slow question'), findsOneWidget);

    // Open another stored chat while the answer is still on its way.
    await tester.tap(find.byKey(const ValueKey('conv-row-c1')));
    await tester.pumpAndSettle();
    expect(find.text('Stored answer.'), findsOneWidget);
    expect(find.text('slow question'), findsNothing);

    final listCallsBefore = server.listCalls;
    late.complete(_json({
      'answer': 'Late answer.',
      'source': 'template',
      'conversation_id': 'late-id',
      'chips': <String>[],
    }));
    await tester.pumpAndSettle();
    expect(find.text('Late answer.'), findsNothing);
    expect(find.text('Stored answer.'), findsOneWidget);
    expect(server.listCalls, listCallsBefore + 1,
        reason: 'the exchange may be stored on the server, refresh the list');

    server.onChat = null;
    await _type(tester, 'next question');
    await tester.pumpAndSettle();
    expect(server.chatBodies.last['conversation_id'], 'c1');
  });

  testWidgets('new chat while sending also drops the late reply',
      (tester) async {
    _wide(tester);
    final server = _Server();
    final late = Completer<http.Response>();
    server.onChat = (_) => late.future;
    await tester.pumpWidget(server.screen());
    await tester.pumpAndSettle();
    await _type(tester, 'slow question');
    await tester.tap(find.byKey(const ValueKey('new-chat-button')));
    await tester.pumpAndSettle();
    late.complete(_json({'answer': 'Late answer.', 'source': 'template'}));
    await tester.pumpAndSettle();
    expect(find.text('Late answer.'), findsNothing);
    expect(find.text('slow question'), findsNothing);
  });

  testWidgets('a failed rename shows a snackbar and keeps the title',
      (tester) async {
    _phone(tester);
    final server = _Server();
    await tester.pumpWidget(server.screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-conversations-button')));
    await tester.pumpAndSettle();
    await _openMenu(tester, 'c1', 'Rename conversation');
    await tester.enterText(
        find.byKey(const ValueKey('rename-chat-field')), 'Other');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Could not rename the conversation.'), findsOneWidget);
    expect(find.text('Morning ride'), findsOneWidget);
  });

  testWidgets('a failed delete shows a snackbar and keeps the row',
      (tester) async {
    _phone(tester);
    final server = _Server()
      ..onDelete = (_) => http.Response('boom', 500);
    await tester.pumpWidget(server.screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-conversations-button')));
    await tester.pumpAndSettle();
    await _openMenu(tester, 'c1', 'Delete conversation');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Could not delete the conversation.'), findsOneWidget);
    expect(find.text('Morning ride'), findsOneWidget);
  });

  testWidgets('cancelling the delete dialog sends no request', (tester) async {
    _phone(tester);
    final server = _Server();
    await tester.pumpWidget(server.screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-conversations-button')));
    await tester.pumpAndSettle();
    await _openMenu(tester, 'c1', 'Delete conversation');
    expect(find.text('Delete conversation?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(server.deleteCalls, 0);
    expect(find.text('Morning ride'), findsOneWidget);
  });

  testWidgets('deleting the open conversation clears the transcript',
      (tester) async {
    _wide(tester);
    final server = _Server();
    await tester.pumpWidget(server.screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conv-row-c1')));
    await tester.pumpAndSettle();
    expect(find.text('Stored answer.'), findsOneWidget);
    await _openMenu(tester, 'c1', 'Delete conversation');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Stored answer.'), findsNothing);
    await _type(tester, 'fresh question');
    await tester.pumpAndSettle();
    expect(server.chatBodies.last['conversation_id'], isNull);
  });

  testWidgets('a failed search shows an error, not "no results", and retries',
      (tester) async {
    _phone(tester);
    final server = _Server()..onSearch = (_) => http.Response('boom', 500);
    await tester.pumpWidget(server.screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-conversations-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('conversation-search-field')), 'coolant');
    await tester.pumpAndSettle();
    expect(find.text('Search failed. Try again.'), findsOneWidget);
    expect(find.text('No matching messages found.'), findsNothing);

    server.onSearch = (_) => _json({'hits': []});
    await tester.tap(find.byKey(const ValueKey('conversation-retry-button')));
    await tester.pumpAndSettle();
    expect(find.text('Search failed. Try again.'), findsNothing);
    expect(find.text('No matching messages found.'), findsOneWidget);
  });

  for (final failure in <String, FutureOr<http.Response> Function(http.Request)>{
    'unreachable': (_) => throw http.ClientException('down'),
    'server error': (_) => http.Response('boom', 500),
  }.entries) {
    testWidgets(
        'first list load failing (${failure.key}) is retried and shows the feature once it works',
        (tester) async {
      _phone(tester);
      final server = _Server()..onList = failure.value;
      await tester.pumpWidget(server.screen());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open-conversations-button')),
          findsNothing);

      // The host comes back; the next answer retries the list.
      server.onList = null;
      await _type(tester, 'hello there');
      await tester.pumpAndSettle();
      expect(server.listCalls, greaterThanOrEqualTo(2));
      expect(find.byKey(const ValueKey('open-conversations-button')),
          findsOneWidget);
    });
  }

  testWidgets(
      'a failed reload keeps the loaded list; an empty list shows an error with a retry button',
      (tester) async {
    _phone(tester);
    final server = _Server()..convs = [];
    await tester.pumpWidget(server.screen());
    await tester.pumpAndSettle();
    // Loaded once (empty), then the server starts failing.
    server.onList = (_) => http.Response('boom', 500);
    await tester.tap(find.byKey(const ValueKey('open-conversations-button')));
    await tester.pumpAndSettle();
    expect(find.text('Could not load your conversations.'), findsOneWidget);
    expect(find.text('No saved conversations yet.'), findsNothing);

    server
      ..convs = [_conv('c1', 'Morning ride')]
      ..onList = null;
    await tester.tap(find.byKey(const ValueKey('conversation-retry-button')));
    await tester.pumpAndSettle();
    expect(find.text('Morning ride'), findsOneWidget);
    expect(find.text('Could not load your conversations.'), findsNothing);
  });

  for (final status in [403, 404]) {
    testWidgets('$status hides the sidebar and the header button for good',
        (tester) async {
      final server = _Server()
        ..onList = (_) => http.Response('no', status);
      _wide(tester);
      await tester.pumpWidget(server.screen());
      await tester.pumpAndSettle();
      expect(find.byType(ConversationListPane), findsNothing);
      expect(find.byKey(const ValueKey('open-conversations-button')),
          findsNothing);

      _phone(tester);
      await tester.pumpWidget(server.screen());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open-conversations-button')),
          findsNothing);
      // Not retried after an answer either.
      final calls = server.listCalls;
      await _type(tester, 'hello there');
      await tester.pumpAndSettle();
      expect(server.listCalls, calls);
    });
  }

  testWidgets('cancelling "delete all facts" sends no request',
      (tester) async {
    var deletes = 0;
    final mock = MockClient((req) async {
      if (req.method == 'GET' && req.url.path == '/assistant/memory') {
        return _json({
          'facts': [
            {
              'key': 'tyres',
              'value': 'Dunlop Trailmax',
              'created': '2026-11-25T11:00:00Z',
              'updated': '2026-11-25T11:00:00Z',
            },
          ],
        });
      }
      if (req.method == 'DELETE') deletes++;
      return http.Response('', 204);
    });
    await tester.pumpWidget(_app(AssistantMemoryScreen(
      baseUrl: 'http://127.0.0.1:8000',
      token: 'user-tok-1234',
      client: ConversationsClient(httpClient: mock),
      exporter: (_, __) async {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('memory-delete-all-button')));
    await tester.pumpAndSettle();
    expect(find.text('Delete all saved facts?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    expect(find.text('Dunlop Trailmax'), findsOneWidget);
  });
}
