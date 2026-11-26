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

void main() {
  testWidgets(
      'wide assistant shows left conversation pane, loads chat, continues with conversation_id and follow-up chips',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final chatBodies = <Map<String, Object?>>[];
    final convs = <Map<String, Object?>>[
      {
        'id': 'conv-1',
        'title': 'Last ride check',
        'created': '2026-11-26T10:00:00Z',
        'updated': '2026-11-26T10:05:00Z',
        'mode': 'data',
      },
    ];
    final mock = MockClient((req) async {
      if (req.method == 'GET' && req.url.path == '/conversations') {
        return http.Response(
            jsonEncode({'conversations': convs, 'next_before': null}), 200);
      }
      if (req.method == 'GET' && req.url.path == '/conversations/conv-1') {
        return http.Response(
          jsonEncode({
            'conversation': convs[0],
            'messages': [
              {
                'id': 1,
                'role': 'user',
                'text': 'How was my last ride?',
                'created': '2026-11-26T10:00:00Z',
              },
              {
                'id': 2,
                'role': 'assistant',
                'text': 'You rode 11.0 km.',
                'source': 'template',
                'created': '2026-11-26T10:00:02Z',
              },
            ],
          }),
          200,
        );
      }
      if (req.method == 'GET' && req.url.path == '/assistant/active') {
        return http.Response(
          jsonEncode({
            'provider_id': 'local',
            'label': 'Local model',
            'model': 'qwen2.5-1.5b',
            'cloud': false,
            'selected_provider_id': 'local',
            'fallback_reason': null,
          }),
          200,
        );
      }
      if (req.method == 'POST' && req.url.path == '/chat') {
        final body = jsonDecode(req.body) as Map<String, Object?>;
        chatBodies.add(body);
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'answer': 'Coolant peaked at 92 °C.',
            'source': 'template',
            'conversation_id': body['temporary'] == true ? null : 'conv-1',
            'chips': ['What about the battery?'],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(_app(AssistantScreen(
      settingsStore: signedInStore(),
      client: ChatClient(httpClient: mock),
      providerClient: AssistantProviderClient(httpClient: mock),
      conversationsClient: ConversationsClient(httpClient: mock),
      voice: _voice(),
    )));
    await tester.pumpAndSettle();

    expect(find.byType(ConversationListPane), findsOneWidget);
    expect(find.text('Last ride check'), findsOneWidget);

    // Load stored conversation.
    await tester.tap(find.byKey(const ValueKey('conv-row-conv-1')));
    await tester.pumpAndSettle();
    expect(find.text('You rode 11.0 km.'), findsOneWidget);

    // Continue conversation -> sends conversation_id and displays follow-up chip.
    await tester.enterText(find.byType(TextField).last, 'What about coolant?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(chatBodies.last['conversation_id'], 'conv-1');
    expect(chatBodies.last['temporary'], isNull);
    expect(find.text('Coolant peaked at 92 °C.'), findsOneWidget);
    expect(find.text('What about the battery?'), findsOneWidget);

    // Tap follow-up chip -> sends chip text in same conversation.
    await tester.tap(find.text('What about the battery?'));
    await tester.pumpAndSettle();
    expect(chatBodies.last['message'], 'What about the battery?');
    expect(chatBodies.last['conversation_id'], 'conv-1');

    // Toggle temporary chat -> banner appears, sends temporary: true, no conversation_id.
    await tester.tap(find.byKey(const ValueKey('temporary-chat-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('temporary-chat-banner')), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Quick check');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(chatBodies.last['temporary'], isTrue);
    expect(chatBodies.last['conversation_id'], isNull);
  });

  testWidgets(
      'phone assistant opens conversations sheet with search, rename, delete (confirm) and new chat',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var title = 'Morning ride';
    var deleted = false;
    final mock = MockClient((req) async {
      if (req.method == 'GET' && req.url.path == '/conversations') {
        return http.Response(
          jsonEncode({
            'conversations': deleted
                ? <Object>[]
                : [
                    {
                      'id': 'c1',
                      'title': title,
                      'created': '2026-11-26T08:00:00Z',
                      'updated': '2026-11-26T08:10:00Z',
                      'mode': 'data',
                    },
                  ],
            'next_before': null,
          }),
          200,
        );
      }
      if (req.method == 'GET' && req.url.path == '/conversations/search') {
        return http.Response(
          jsonEncode({
            'hits': [
              {
                'conversation_id': 'c1',
                'title': title,
                'message_id': 1,
                'role': 'user',
                'snippet': 'coolant temp check',
                'created': '2026-11-26T08:00:00Z',
              },
            ],
            'engine': 'fts5',
          }),
          200,
        );
      }
      if (req.method == 'PATCH' && req.url.path == '/conversations/c1') {
        final body = jsonDecode(req.body) as Map<String, Object?>;
        title = body['title'] as String;
        return http.Response(
          jsonEncode({
            'id': 'c1',
            'title': title,
            'created': '2026-11-26T08:00:00Z',
            'updated': '2026-11-26T08:12:00Z',
            'mode': 'data',
          }),
          200,
        );
      }
      if (req.method == 'DELETE' && req.url.path == '/conversations/c1') {
        deleted = true;
        return http.Response('', 204);
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(_app(AssistantScreen(
      settingsStore: signedInStore(),
      client: ChatClient(httpClient: mock),
      providerClient: AssistantProviderClient(httpClient: mock),
      conversationsClient: ConversationsClient(httpClient: mock),
      voice: _voice(),
    )));
    await tester.pumpAndSettle();

    // Narrow layout hides sidebar and shows header button.
    expect(find.byType(ConversationListPane), findsNothing);
    await tester.tap(find.byKey(const ValueKey('open-conversations-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationListPane), findsOneWidget);
    expect(find.text('Morning ride'), findsOneWidget);

    // Search conversations.
    await tester.enterText(
        find.byKey(const ValueKey('conversation-search-field')), 'coolant');
    await tester.pumpAndSettle();
    expect(find.text('coolant temp check'), findsOneWidget);

    // Clear search back to list.
    await tester.enterText(
        find.byKey(const ValueKey('conversation-search-field')), '');
    await tester.pumpAndSettle();

    // Rename conversation.
    await tester.tap(find.byKey(const ValueKey('conv-menu-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename conversation'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('rename-chat-field')), 'Commute notes');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Commute notes'), findsOneWidget);

    // Delete conversation with confirmation.
    await tester.tap(find.byKey(const ValueKey('conv-menu-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete conversation'));
    await tester.pumpAndSettle();
    expect(find.text('Delete conversation?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(find.text('No saved conversations yet.'), findsOneWidget);
  });

  testWidgets(
      'assistant memory screen lists, edits, deletes one, deletes all and exports chats',
      (tester) async {
    final facts = <Map<String, Object?>>[
      {
        'key': 'exhaust',
        'value': 'Slip-on exhaust',
        'created': '2026-11-25T10:00:00Z',
        'updated': '2026-11-25T10:00:00Z',
      },
      {
        'key': 'tyres',
        'value': 'Dunlop Trailmax',
        'created': '2026-11-25T11:00:00Z',
        'updated': '2026-11-25T11:00:00Z',
      },
    ];
    String? exportedFile;
    String? exportedContent;

    final mock = MockClient((req) async {
      if (req.method == 'GET' && req.url.path == '/assistant/memory') {
        return http.Response(jsonEncode({'facts': facts}), 200);
      }
      if (req.method == 'PUT' && req.url.path == '/assistant/memory/exhaust') {
        final body = jsonDecode(req.body) as Map<String, Object?>;
        facts[0]['value'] = body['value'];
        return http.Response(jsonEncode(facts[0]), 200);
      }
      if (req.method == 'DELETE' && req.url.path == '/assistant/memory/tyres') {
        facts.removeWhere((f) => f['key'] == 'tyres');
        return http.Response('', 204);
      }
      if (req.method == 'DELETE' && req.url.path == '/assistant/memory') {
        final n = facts.length;
        facts.clear();
        return http.Response(jsonEncode({'deleted': n}), 200);
      }
      if (req.method == 'GET' && req.url.path == '/conversations/export') {
        return http.Response(
          jsonEncode({
            'exported': '2026-11-26T12:00:00Z',
            'conversations': [],
            'memory': facts,
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(_app(AssistantMemoryScreen(
      baseUrl: 'http://127.0.0.1:8000',
      token: 'user-tok-1234',
      client: ConversationsClient(httpClient: mock),
      exporter: (filename, content) async {
        exportedFile = filename;
        exportedContent = content;
      },
    )));
    await tester.pumpAndSettle();

    expect(find.text('Slip-on exhaust'), findsOneWidget);
    expect(find.text('Dunlop Trailmax'), findsOneWidget);

    // Edit fact value.
    await tester.tap(find.byKey(const ValueKey('memory-edit-exhaust')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('memory-edit-field')), 'Full titanium exhaust');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Full titanium exhaust'), findsOneWidget);

    // Delete single fact.
    await tester.tap(find.byKey(const ValueKey('memory-delete-tyres')));
    await tester.pumpAndSettle();
    expect(find.text('Dunlop Trailmax'), findsNothing);

    // Export chats.
    await tester.tap(find.byKey(const ValueKey('export-chats-row')));
    await tester.pumpAndSettle();
    expect(exportedFile, 'vehicle-assistant-chats.json');
    expect(exportedContent, contains('Full titanium exhaust'));

    // Delete all facts with confirmation.
    await tester.tap(find.byKey(const ValueKey('memory-delete-all-button')));
    await tester.pumpAndSettle();
    expect(find.text('Delete all saved facts?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(facts, isEmpty);
    expect(find.text('Full titanium exhaust'), findsNothing);
  });
}
