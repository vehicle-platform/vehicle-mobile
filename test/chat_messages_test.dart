import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/models/chat_message.dart';
import 'package:vehicle_mobile/ui/rides/quantities.dart';
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

  group('chatData', () {
    final l = lookupAppLocalizations(const Locale('en'));

    test('turns numeric keys into labels and units, drops ids and strings', () {
      final data = chatData({
        'session_id': 'abc',
        'defs_version': 'v0.31.0',
        'distance_km': 12.40,
        'max_speed_kmh': 98,
        'coolant_c': 91,
        'note': 'ok',
      }, l);
      expect([for (final d in data) (d.label, d.value, d.unit)], [
        ('Distance', '12.4', 'km'),
        ('Max speed', '98', 'km/h'),
        ('Coolant', '91', '\u00b0C'),
      ]);
    });

    test('a ride summary shows only rider quantities with human labels', () {
      final data = chatData({
        'session_id': '20261118-090000-8394',
        'ride_definition': 'session',
        'defs_version': 'v0.31.0',
        'signals': [
          {'name': 'speedometer_error', 'status': 'missing_inputs'},
          {'name': 'ride_ltft_mean', 'status': 'computed', 'unit': '%', 'kind': 'scalar', 'value': 1.5},
          {'name': 'ride_idle_time', 'status': 'computed', 'unit': 's', 'kind': 'scalar', 'value': 135.8},
          {'name': 'ride_distance', 'status': 'computed', 'unit': 'km', 'kind': 'scalar', 'value': 20.645805},
          {'name': 'ride_stop_count', 'status': 'computed', 'unit': 'count', 'kind': 'scalar', 'value': 2.0},
          {'name': 'ride_time', 'status': 'computed', 'unit': 's', 'kind': 'scalar', 'value': 1215.0},
        ],
      }, l);
      expect([for (final d in data) (d.label, d.value, d.unit)], [
        ('Distance', '20.6', 'km'),
        ('Ride time', '20 min 15 s', null),
        ('Stops', '2', null),
        ('Idle time', '2 min 16 s', null),
      ]);
      final text = data.map((d) => d.label).join(' ');
      expect(text.toLowerCase(), isNot(contains('session')));
      expect(text.toLowerCase(), isNot(contains('version')));
      expect(text.toLowerCase(), isNot(contains('status')));
    });

    test('signal stats use the server label and the cap', () {
      final data = chatData({
        'values': [
          for (var i = 0; i < 10; i++)
            {'name': 'coolant_temp_x$i', 'unit': 'degC', 'value': 1.0 * i, 'label': 'coolant temp $i'},
        ],
      }, l, max: 4);
      expect(data, hasLength(4));
      expect(data.first.label, 'Coolant temp 0');
      expect(data.first.unit, '\u00b0C');
    });

    test('readable fallback when nothing is known', () {
      expect(readableName('ride_ltft_mean'), 'Ltft mean');
    });
  });

  test('model names show as basenames without .gguf', () {
    expect(cleanModelName('/srv/models/qwen2.5-7b-q4.gguf'), 'qwen2.5-7b-q4');
    expect(cleanModelName('C:\\m\\x.GGUF'), 'x');
    expect(cleanModelName('gemini-2.0-flash'), 'gemini-2.0-flash');
    expect(
        const AnsweringModel(
                providerId: 'local', label: 'Local', model: '/m/a.gguf')
            .caption,
        'Local \u00b7 a');
  });

  group('chips', () {
    test('absent chips mean none; non-strings are ignored; capped', () {
      expect(ChatAnswer.fromJson({'answer': 'a', 'source': 'llm'}).chips,
          isEmpty);
      expect(
          ChatAnswer.fromJson({
            'answer': 'a',
            'source': 'llm',
            'chips': ['One', 3, null, '  ', ' Two ']
          }).chips,
          ['One', 'Two']);
      expect(
          ChatAnswer.fromJson({
            'answer': 'a',
            'source': 'llm',
            'chips': [for (var i = 0; i < 10; i++) 'c$i']
          }).chips,
          hasLength(chatMaxChips));
      expect(
          ChatAnswer.fromJson({'answer': 'a', 'source': 'llm', 'chips': 'x'})
              .chips,
          isEmpty);
    });
  });

  group('TranscriptEntry', () {
    testWidgets('answer: plain text, data card values with units, collapsed tool rows',
        (tester) async {
      final message = ChatMessage.fromAnswer(const ChatAnswer(
        answer: 'Your last ride was 12.4 km.',
        source: ChatSource.llm,
        tool: ChatToolCall(
            name: 'get_ride_summary', arguments: {'session_id': 'abc'}),
        result: {
          'distance_km': 12.4,
          'extremes': {'max_speed': 98},
        },
        elapsedMs: 700,
      ));
      await tester.pumpWidget(_host(TranscriptEntry(message: message)));

      expect(find.text('Your last ride was 12.4 km.'), findsOneWidget);
      expect(find.text('ASSISTANT'), findsOneWidget);
      expect(find.textContaining('computed by', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('get_ride_summary', findRichText: true),
          findsOneWidget);
      // The data card shows labelled values with units right away.
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('12.4'), findsOneWidget);
      expect(find.text('km'), findsOneWidget);
      expect(find.text('98.0'), findsOneWidget);
      // Raw rows only when expanded.
      expect(find.text('result.distance_km'), findsNothing);

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('session_id'), findsOneWidget);
      expect(find.text('abc'), findsOneWidget);
      expect(find.text('result.distance_km'), findsOneWidget);
      expect(find.text('result.extremes.max_speed'), findsOneWidget);
    });

    testWidgets('a template answer has no tool card without a tool',
        (tester) async {
      await tester.pumpWidget(_host(TranscriptEntry(
        message: ChatMessage.fromAnswer(const ChatAnswer(
            answer: 'No recorded faults.', source: ChatSource.template)),
      )));
      expect(find.text('VERIFIED FROM DATA'), findsOneWidget);
      expect(find.text('Template answer (no model)'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
    });

    testWidgets('a question is a plain timestamped line without any badge',
        (tester) async {
      await tester.pumpWidget(_host(TranscriptEntry(
          message: ChatMessage.user('hello', at: DateTime(2026, 11, 25, 9, 5)))));
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('09:05'), findsOneWidget);
      expect(find.byType(SourceBadge), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('follow-up chips tap through; none renders nothing',
        (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(_host(
          FollowUpChips(chips: const ['Coolant', 'Battery'], onTap: tapped.add)));
      await tester.tap(find.widgetWithText(ActionChip, 'Battery'));
      expect(tapped, ['Battery']);
      await tester.pumpWidget(
          _host(FollowUpChips(chips: const [], onTap: tapped.add)));
      expect(find.byType(ActionChip), findsNothing);
    });
  });
}
