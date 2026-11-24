import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vehicle_mobile/models/chat_message.dart';
import 'package:vehicle_mobile/ui/assistant/chat_widgets.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

Widget _host(Widget child) => MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('flattenChatValue', () {
    Map<String, String> rows(Object? v, {String key = ''}) =>
        {for (final r in flattenChatValue(v, key: key)) r.key: r.value};

    test('flattens nested maps into dotted keys and keeps values verbatim', () {
      expect(
          rows({
            'a': {'b': 1, 'c': 2.50},
            'd': 'x',
            'e': null
          }),
          {
            'a.b': '1',
            'a.c': '2.5',
            'd': 'x',
            'e': 'null',
          });
    });

    test('truncates long lists with the item count', () {
      final r = rows({
        'laps': [
          for (var i = 0; i < 8; i++) {'n': i}
        ],
      });
      expect(r['laps'], '8 items');
      expect(r['laps[0].n'], '0');
      expect(r['laps[4].n'], '4');
      expect(r.containsKey('laps[5].n'), isFalse);
      expect(r['laps[...]'], '+3 more');
    });

    test('a scalar or string result becomes one row under the given key', () {
      expect(rows('ok', key: 'result'), {'result': 'ok'});
      expect(rows([1, 2], key: 'result'),
          {'result': '2 items', 'result[0]': '1', 'result[1]': '2'});
    });

    test('caps the number of rows', () {
      final big = {for (var i = 0; i < 200; i++) 'k$i': i};
      final flat = flattenChatValue(big);
      expect(flat.length, lessThanOrEqualTo(61));
      expect(flat.last.value, 'truncated');
    });
  });

  group('ChatBubble', () {
    testWidgets('shows the answer, an LLM badge and a collapsed tool card',
        (tester) async {
      final message = ChatMessage.fromAnswer(const ChatAnswer(
        answer: 'Son sürüşün 12.4 km idi.',
        source: ChatSource.llm,
        tool: ChatToolCall(
            name: 'get_ride_summary', arguments: {'session_id': 'abc'}),
        result: {
          'distance_km': 12.4,
          'extremes': {'max_speed': 98},
        },
        elapsedMs: 700,
      ));
      await tester.pumpWidget(_host(ChatBubble(message: message)));

      expect(find.text('Son sürüşün 12.4 km idi.'), findsOneWidget);
      expect(find.text('Usta'), findsWidgets);
    expect(find.text('LLM'), findsNothing);
      expect(find.textContaining('computed by', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('get_ride_summary', findRichText: true),
          findsOneWidget);
      // Collapsed: no rows yet.
      expect(find.text('12.4'), findsNothing);

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('session_id'), findsOneWidget);
      expect(find.text('abc'), findsOneWidget);
      expect(find.text('result.distance_km'), findsOneWidget);
      expect(find.text('12.4'), findsOneWidget);
      expect(find.text('result.extremes.max_speed'), findsOneWidget);
      expect(find.text('98'), findsOneWidget);
    });

    testWidgets(
        'a template answer shows the template badge and no tool card without a tool',
        (tester) async {
      await tester.pumpWidget(_host(ChatBubble(
        message: ChatMessage.fromAnswer(const ChatAnswer(
            answer: 'Kayıtlı arıza yok.', source: ChatSource.template)),
      )));
      expect(find.text('Veriden doğrulandı'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
    });

    testWidgets('a user message has no badge', (tester) async {
      await tester.pumpWidget(
          _host(const ChatBubble(message: ChatMessage.user('merhaba'))));
      expect(find.text('merhaba'), findsOneWidget);
      expect(find.byType(SourceBadge), findsNothing);
    });
  });
}
