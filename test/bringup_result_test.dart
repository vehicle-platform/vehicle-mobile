import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_mobile/models/bringup_result.dart';

Map<String, Object?> check({
  String id = 'report_status',
  String status = 'pass',
  Object? measured = const {'status': 'ok'},
  String expected = 'report status ok',
  String source = 'hardware-integration.md §6 B0',
  String note = 'The session report’s own verdict.',
}) =>
    {
      'id': id,
      'status': status,
      'measured': measured,
      'expected': expected,
      'source': source,
      'note': note,
    };

Map<String, Object?> body({
  String verdict = 'pass',
  List<Map<String, Object?>>? checks,
  List<String> needsYou = const [],
  List<String> warnings = const [],
}) =>
    {
      'session_id': '20260116-120000-ab12',
      'gate': 'V0',
      'verdict': verdict,
      'checks': checks ?? [check()],
      'needs_you': needsYou,
      'warnings': warnings,
    };

void main() {
  test('parses a pass in server order', () {
    final result = BringupResult.fromJson(body(checks: [
      check(id: 'ecu_present'),
      check(id: 'dids_valid', measured: {
        'ENGINE_SPEED': {'valid_count': 12}
      }),
      check(id: 'step_gap', status: 'warn'),
    ], warnings: [
      'step_gap'
    ]));

    expect(result.sessionId, '20260116-120000-ab12');
    expect(result.gate, 'V0');
    expect(result.verdict, 'pass');
    expect(result.checks.map((c) => c.id),
        ['ecu_present', 'dids_valid', 'step_gap']);
    expect(result.checks[1].measured, {
      'ENGINE_SPEED': {'valid_count': 12}
    });
    expect(result.needsYou, isEmpty);
    expect(result.warnings, ['step_gap']);
  });

  test('parses a fail', () {
    final result = BringupResult.fromJson(body(
      verdict: 'fail',
      checks: [
        check(
            id: 'no_bus_off',
            status: 'fail',
            measured: {'max_bus_off_count': 1})
      ],
    ));

    expect(result.verdict, 'fail');
    expect(result.checks.single.status, 'fail');
    expect(result.checks.single.measured, {'max_bus_off_count': 1});
  });

  test('parses an incomplete result with manual checks', () {
    final result = BringupResult.fromJson(body(
      verdict: 'incomplete',
      checks: [
        check(id: 'at_rest', status: 'manual', measured: null),
        check(
            id: 'rpm_throttle_blip', status: 'manual', measured: {'count': 3}),
      ],
      needsYou: ['at_rest', 'rpm_throttle_blip'],
    ));

    expect(result.verdict, 'incomplete');
    expect(result.needsYou, ['at_rest', 'rpm_throttle_blip']);
    expect(result.checks[0].measured, isNull);
  });

  test('keeps every JSON type of measured', () {
    final values = <Object?>[
      null,
      42,
      1.5,
      'text',
      true,
      [1, 'two', false],
      {
        'key': 1,
        'nested': [true, null],
      },
    ];
    for (final value in values) {
      final result =
          BringupResult.fromJson(body(checks: [check(measured: value)]));
      expect(result.checks.single.measured, value);
    }
  });

  test('throws FormatException on a missing or wrongly typed required field',
      () {
    final missing = body()..remove('gate');
    expect(() => BringupResult.fromJson(missing), throwsFormatException);

    final missingMeasured = body(checks: [check()..remove('measured')]);
    expect(
        () => BringupResult.fromJson(missingMeasured), throwsFormatException);

    final wrongChecks = body()..['checks'] = 'not a list';
    expect(() => BringupResult.fromJson(wrongChecks), throwsFormatException);

    final wrongNeedsYou = body()..['needs_you'] = ['ok', 3];
    expect(() => BringupResult.fromJson(wrongNeedsYou), throwsFormatException);

    final wrongMeasured = body(checks: [check(measured: double.nan)]);
    expect(() => BringupResult.fromJson(wrongMeasured), throwsFormatException);
  });

  test('keeps an unknown status string verbatim', () {
    final result =
        BringupResult.fromJson(body(checks: [check(status: 'future_status')]));
    expect(result.checks.single.status, 'future_status');
  });
}
