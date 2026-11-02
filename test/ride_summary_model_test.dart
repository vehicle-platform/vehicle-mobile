import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_mobile/models/ride_summary.dart';

Map<String, Object?> ridesFixture() => {
      'columns': [
        {'name': 'ride_distance', 'unit': 'km'},
        {'name': 'ride_time', 'unit': 's'},
      ],
      'rows': [
        {
          'session_id': '20260115-120000-abcd',
          'created_utc': '2026-01-15T12:00:00+00:00',
          'values': {'ride_distance': 12.3, 'ride_time': 900.0},
          'flags': {'ride_distance': null, 'ride_time': null},
          'ignored': true,
        },
        {
          'session_id': '20260116-120000-beef',
          'created_utc': null,
          'values': {'ride_distance': null, 'ride_time': null},
          'flags': {'ride_distance': 'missing', 'ride_time': 'not_ready'},
        },
      ],
      'skipped': 2,
      'ignored': 'extra',
    };

Map<String, Object?> summaryFixture() => {
      'session_id': '20260115-120000-abcd',
      'ride_definition': 'session',
      'defs_version': 'v0.19.1',
      'signals': [
        {
          'name': 'ride_distance',
          'status': 'computed',
          'unit': 'km',
          'range': [0.0, 2000.0],
          'kind': 'scalar',
          'value': 12.3,
          'flag': null,
          'ignored': true,
        },
        {
          'name': 'ride_coolant_time_at_temp',
          'status': 'computed',
          'unit': 's',
          'range': [0.0, 86400.0],
          'kind': 'binned',
          'axes': [
            {
              'input': 'did.COOLANT_TEMP',
              'unit': 'degC',
              'edges': [
                [30.0, 40.0],
                [40.0, 50.0],
              ],
            },
          ],
          'cells': [
            {'index': 0, 'axes': [0], 'value': 41.0, 'flag': null},
            {'index': 1, 'axes': [1], 'value': null, 'flag': 'low'},
          ],
          'total_s': 900.0,
          'outside_s': 3.0,
        },
        {
          'name': 'derived.operating_point_time',
          'status': 'computed',
          'unit': 's',
          'range': [0.0, 86400.0],
          'kind': 'binned',
          'axes': [
            {
              'input': 'did.VEHICLE_SPEED',
              'unit': 'km/h',
              'edges': [
                [0.0, 30.0],
                [30.0, 60.0],
              ],
            },
            {
              'input': 'did.ENGINE_SPEED',
              'unit': 'rpm',
              'edges': [
                [0.0, 3000.0],
                [3000.0, 6000.0],
              ],
            },
          ],
          'cells': [
            {'index': 0, 'axes': [0, 0], 'value': 12.0, 'flag': null},
            {'index': 3, 'axes': [1, 1], 'value': 4.0, 'flag': 'high'},
          ],
          'total_s': 120.0,
          'outside_s': 1.0,
          'defs_mismatch': true,
        },
        {
          'name': 'ride_idle_time',
          'status': 'not_ready',
          'reason': 'waiting for a complete ride',
          'pending_inputs': ['did.VEHICLE_SPEED'],
          'ignored': 1,
        },
        {
          'name': 'ride_fuel_used',
          'status': 'error',
          'message': 'no fuel input',
          'missing': ['did.FUEL_LEVEL'],
        },
      ],
      'ignored': false,
    };

Map<String, Object?> copy(Map<String, Object?> source) =>
    (jsonDecode(jsonEncode(source)) as Map).cast<String, Object?>();

Map<String, Object?> ridesWithout(String key) {
  final json = copy(ridesFixture());
  json.remove(key);
  return json;
}

Map<String, Object?> ridesColumnWithout(String key) {
  final json = copy(ridesFixture());
  ((json['columns'] as List).first as Map<String, Object?>).remove(key);
  return json;
}

Map<String, Object?> ridesRowWithout(String key) {
  final json = copy(ridesFixture());
  ((json['rows'] as List).first as Map<String, Object?>).remove(key);
  return json;
}

Map<String, Object?> summaryWithout(String key) {
  final json = copy(summaryFixture());
  json.remove(key);
  return json;
}

Map<String, Object?> summarySignalWithout(int index, String key) {
  final json = copy(summaryFixture());
  ((json['signals'] as List)[index] as Map<String, Object?>).remove(key);
  return json;
}

Map<String, Object?> summaryAxisWithout(int signal, int axis, String key) {
  final json = copy(summaryFixture());
  final signalMap = (json['signals'] as List)[signal] as Map<String, Object?>;
  ((signalMap['axes'] as List)[axis] as Map<String, Object?>).remove(key);
  return json;
}

Map<String, Object?> summaryCellWithout(int signal, int cell, String key) {
  final json = copy(summaryFixture());
  final signalMap = (json['signals'] as List)[signal] as Map<String, Object?>;
  ((signalMap['cells'] as List)[cell] as Map<String, Object?>).remove(key);
  return json;
}

void main() {
  group('RidesTable.fromJson', () {
    test('reads columns, rows, nullable values and the skipped count', () {
      final table = RidesTable.fromJson(ridesFixture());

      expect(table.columns.map((column) => column.name), ['ride_distance', 'ride_time']);
      expect(table.columns.map((column) => column.unit), ['km', 's']);
      expect(table.skipped, 2);
      expect(table.rows, hasLength(2));
      expect(table.rows.first.sessionId, '20260115-120000-abcd');
      expect(table.rows.first.createdUtc, DateTime.utc(2026, 1, 15, 12));
      expect(table.rows.first.createdUtc!.isUtc, isTrue);
      expect(table.rows.first.values, {'ride_distance': 12.3, 'ride_time': 900.0});
      expect(table.rows.first.flags, {'ride_distance': null, 'ride_time': null});
      expect(table.rows[1].createdUtc, isNull);
      expect(table.rows[1].values, {'ride_distance': null, 'ride_time': null});
      expect(table.rows[1].flags, {'ride_distance': 'missing', 'ride_time': 'not_ready'});
    });

    test('treats an offsetless created_utc as UTC', () {
      final json = ridesFixture();
      ((json['rows'] as List).first as Map<String, Object?>)['created_utc'] = '2026-01-15T12:00:00';
      final table = RidesTable.fromJson(json);
      expect(table.rows.first.createdUtc, DateTime.utc(2026, 1, 15, 12));
    });
  });

  group('RideSummary.fromJson', () {
    test('keeps the response order and parses scalar, binned and unavailable signals', () {
      final summary = RideSummary.fromJson(summaryFixture());

      expect(summary.sessionId, '20260115-120000-abcd');
      expect(summary.rideDefinition, 'session');
      expect(summary.defsVersion, 'v0.19.1');
      expect(summary.signals, hasLength(5));
      expect(summary.signals.map((signal) => signal.name), [
        'ride_distance',
        'ride_coolant_time_at_temp',
        'derived.operating_point_time',
        'ride_idle_time',
        'ride_fuel_used',
      ]);

      final scalar = summary.signals[0] as ScalarSummary;
      expect(scalar.status, 'computed');
      expect(scalar.unit, 'km');
      expect(scalar.range.min, 0);
      expect(scalar.range.max, 2000);
      expect(scalar.value, 12.3);
      expect(scalar.flag, isNull);

      final oneAxis = summary.signals[1] as BinnedSummary;
      expect(oneAxis.axes, hasLength(1));
      expect(oneAxis.axes.single.input, 'did.COOLANT_TEMP');
      expect(oneAxis.axes.single.edges[0].min, 30);
      expect(oneAxis.cells[1].value, isNull);
      expect(oneAxis.cells[1].flag, 'low');
      expect(oneAxis.totalS, 900);
      expect(oneAxis.outsideS, 3);
      expect(oneAxis.defsMismatch, isFalse);

      final twoAxes = summary.signals[2] as BinnedSummary;
      expect(twoAxes.axes, hasLength(2));
      expect(twoAxes.cells[1].axes, [1, 1]);
      expect(twoAxes.cells[1].flag, 'high');
      expect(twoAxes.defsMismatch, isTrue);

      final notReady = summary.signals[3] as UnavailableSummary;
      expect(notReady.status, 'not_ready');
      expect(notReady.reason, 'waiting for a complete ride');
      expect(notReady.pendingInputs, ['did.VEHICLE_SPEED']);

      final error = summary.signals[4] as UnavailableSummary;
      expect(error.status, 'error');
      expect(error.message, 'no fuel input');
      expect(error.missing, ['did.FUEL_LEVEL']);
    });

    test('rejects an unknown computed kind', () {
      final json = summaryFixture();
      ((json['signals'] as List).first as Map<String, Object?>)['kind'] = 'matrix';
      expect(
        () => RideSummary.fromJson(json),
        throwsA(isA<FormatException>().having((error) => error.message, 'message', contains('kind'))),
      );
    });
  });

  group('strict required fields', () {
    final ridesCases = <(String, Map<String, Object?>)>[
      ('columns', ridesWithout('columns')),
      ('rows', ridesWithout('rows')),
      ('skipped', ridesWithout('skipped')),
      ('name', ridesColumnWithout('name')),
      ('unit', ridesColumnWithout('unit')),
      ('session_id', ridesRowWithout('session_id')),
      ('values', ridesRowWithout('values')),
      ('flags', ridesRowWithout('flags')),
    ];
    for (final (field, payload) in ridesCases) {
      test('RidesTable rejects a missing $field', () {
        expect(
          () => RidesTable.fromJson(payload),
          throwsA(isA<FormatException>().having((error) => error.message, 'message', contains(field))),
        );
      });
    }

    final summaryCases = <(String, String, Map<String, Object?>)>[
      ('session_id', 'session_id', summaryWithout('session_id')),
      ('signals', 'signals', summaryWithout('signals')),
      ('name', 'name', summarySignalWithout(0, 'name')),
      ('status', 'status', summarySignalWithout(0, 'status')),
      ('kind', 'kind', summarySignalWithout(0, 'kind')),
      ('unit', 'unit', summarySignalWithout(0, 'unit')),
      ('range', 'range', summarySignalWithout(0, 'range')),
      ('axes', 'axes', summarySignalWithout(1, 'axes')),
      ('cells', 'cells', summarySignalWithout(1, 'cells')),
      ('total_s', 'total_s', summarySignalWithout(1, 'total_s')),
      ('outside_s', 'outside_s', summarySignalWithout(1, 'outside_s')),
      ('input', 'input', summaryAxisWithout(1, 0, 'input')),
      ('axis unit', 'axes[0].unit', summaryAxisWithout(1, 0, 'unit')),
      ('edges', 'edges', summaryAxisWithout(1, 0, 'edges')),
      ('index', 'index', summaryCellWithout(1, 0, 'index')),
      ('cell axes', 'cells[0].axes', summaryCellWithout(1, 0, 'axes')),
      ('name (unavailable)', 'signals[3].name', summarySignalWithout(3, 'name')),
      ('status (unavailable)', 'signals[3].status', summarySignalWithout(3, 'status')),
    ];
    for (final (description, expected, payload) in summaryCases) {
      test('RideSummary rejects a missing $description', () {
        expect(
          () => RideSummary.fromJson(payload),
          throwsA(isA<FormatException>().having((error) => error.message, 'message', contains(expected))),
        );
      });
    }

    test('rejects wrong types and malformed timestamps', () {
      final wrongValues = copy(ridesFixture());
      ((wrongValues['rows'] as List).first as Map<String, Object?>)['values'] = 'not a map';
      expect(() => RidesTable.fromJson(wrongValues), throwsFormatException);

      final wrongDate = copy(ridesFixture());
      ((wrongDate['rows'] as List).first as Map<String, Object?>)['created_utc'] = 'not a timestamp';
      expect(() => RidesTable.fromJson(wrongDate), throwsFormatException);

      final negativeSkipped = copy(ridesFixture());
      negativeSkipped['skipped'] = -1;
      expect(() => RidesTable.fromJson(negativeSkipped), throwsFormatException);

      final badRange = copy(summaryFixture());
      ((badRange['signals'] as List).first as Map<String, Object?>)['range'] = [0.0];
      expect(() => RideSummary.fromJson(badRange), throwsFormatException);

      final badEdges = copy(summaryFixture());
      final axis = (((badEdges['signals'] as List)[1] as Map<String, Object?>)['axes'] as List).first
          as Map<String, Object?>;
      axis['edges'] = 'not a list';
      expect(() => RideSummary.fromJson(badEdges), throwsFormatException);
    });
  });
}
