import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_mobile/models/health_windows.dart';

Map<String, Object?> _copy(Object source) =>
    (jsonDecode(jsonEncode(source)) as Map).cast<String, Object?>();

Map<String, Object?> _report() => {
      'derived_summary': {
        'health_windows': {
          'rule':
              'provisional: Claude\'s reading of D-079 (vehicle-server README)',
          't0_device_ms': 1000,
          'windows': {
            'W3_WARM_IDLE': {
              'qualifying_count': 1,
              'instances': [
                {
                  'start_ms': 3000,
                  'end_ms': 30000,
                  'duration_ms': 27000,
                  'close_reason': 'condition',
                  'qualifies': true,
                  'first_qualifying': true,
                },
                {
                  'start_ms': 40000,
                  'end_ms': 41000,
                  'duration_ms': 1000,
                  'close_reason': 'session_end',
                  'qualifies': false,
                  'first_qualifying': false,
                },
              ],
            },
            'W1_KEY_ON': {'qualifying_count': 0, 'instances': <Object?>[]},
          },
        },
      },
    };

Map<String, Object?> _block() =>
    _copy((_report()['derived_summary'] as Map)['health_windows'] as Map);

Map<String, Object?> _window() =>
    _copy((_block()['windows'] as Map)['W3_WARM_IDLE'] as Map);

Map<String, Object?> _instance() =>
    _copy(((_window()['instances'] as List).first) as Map);

HealthWindowsResult _parseBlock(Map<String, Object?> block) =>
    parseHealthWindows({
      'derived_summary': {'health_windows': block},
    });

void main() {
  group('parseHealthWindows', () {
    test('parses the block, keeps the response order and all fields', () {
      final result = parseHealthWindows(_report());

      expect(result.isOk, isTrue);
      expect(result.reason, isNull);
      final block = result.block!;
      expect(block.rule, contains('provisional'));
      expect(block.t0DeviceMs, 1000);
      expect(block.windows.map((window) => window.key),
          ['W3_WARM_IDLE', 'W1_KEY_ON']);

      final warmIdle = block.windows.first;
      expect(warmIdle.qualifyingCount, 1);
      expect(warmIdle.instances, hasLength(2));
      final first = warmIdle.instances.first;
      expect(first.startMs, 3000);
      expect(first.endMs, 30000);
      expect(first.durationMs, 27000);
      expect(first.closeReason, 'condition');
      expect(first.qualifies, isTrue);
      expect(first.firstQualifying, isTrue);
      expect(warmIdle.instances.last.firstQualifying, isFalse);
      expect(block.windows.last.instances, isEmpty);
    });

    test('a missing derived_summary or health_windows is not in report', () {
      expect(parseHealthWindows(<String, Object?>{}).reason, 'not in report');
      expect(
          parseHealthWindows({'derived_summary': <String, Object?>{}}).reason,
          'not in report');
      expect(parseHealthWindows(null).reason,
          'malformed: report is not an object');
    });

    test('rejects a malformed block or field', () {
      final cases = <String, HealthWindowsResult>{
        'derived_summary is not an object': parseHealthWindows({
          'derived_summary': <Object?>[],
        }),
        'health_windows is not an object': parseHealthWindows({
          'derived_summary': {'health_windows': <Object?>[]},
        }),
        'rule is missing or not a string':
            _parseBlock({..._block(), 'rule': 1}),
        't0_device_ms is missing or not an integer':
            _parseBlock({..._block(), 't0_device_ms': 1.5}),
        'windows is not an object':
            _parseBlock({..._block(), 'windows': <Object?>[]}),
        'W3_WARM_IDLE is not an object': _parseBlock({
          ..._block(),
          'windows': {'W3_WARM_IDLE': <Object?>[]},
        }),
        'qualifying_count is negative': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {..._window(), 'qualifying_count': -1},
          },
        }),
        'qualifying_count is missing or not an integer': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {..._window(), 'qualifying_count': '1'},
          },
        }),
        'instances is not a list': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {..._window(), 'instances': 1},
          },
        }),
        'instances[0] is not an object': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {
              ..._window(),
              'instances': [1],
            },
          },
        }),
        'start_ms is missing or not an integer': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {
              ..._window(),
              'instances': [
                {..._instance(), 'start_ms': 1.5}
              ],
            },
          },
        }),
        'end_ms is missing or not an integer': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {
              ..._window(),
              'instances': [
                {..._instance(), 'end_ms': '30000'}
              ],
            },
          },
        }),
        'end_ms is before start_ms': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {
              ..._window(),
              'instances': [
                {..._instance(), 'end_ms': 2999, 'duration_ms': -1}
              ],
            },
          },
        }),
        'duration_ms is missing or not an integer': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {
              ..._window(),
              'instances': [
                {..._instance(), 'duration_ms': 27000.5}
              ],
            },
          },
        }),
        'duration_ms does not match': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {
              ..._window(),
              'instances': [
                {..._instance(), 'duration_ms': 1}
              ],
            },
          },
        }),
        'close_reason is missing or not a string': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {
              ..._window(),
              'instances': [
                {..._instance(), 'close_reason': 1}
              ],
            },
          },
        }),
        'qualifies is missing or not a boolean': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {
              ..._window(),
              'instances': [
                {..._instance(), 'qualifies': 1}
              ],
            },
          },
        }),
        'first_qualifying is missing or not a boolean': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {
              ..._window(),
              'instances': [
                {..._instance(), 'first_qualifying': 1}
              ],
            },
          },
        }),
        'more than one first_qualifying': _parseBlock({
          ..._block(),
          'windows': {
            'W3_WARM_IDLE': {
              ..._window(),
              'instances': [
                _instance(),
                {
                  ..._instance(),
                  'start_ms': 40000,
                  'end_ms': 41000,
                  'duration_ms': 1000,
                },
              ],
            },
          },
        }),
      };

      for (final entry in cases.entries) {
        expect(entry.value.isOk, isFalse, reason: entry.key);
        expect(entry.value.reason, startsWith('malformed: '),
            reason: entry.key);
        expect(entry.value.reason, contains(entry.key), reason: entry.key);
      }
    });
  });
}
