/// One criterion of a `GET /sessions/{id}/bringup` answer.
class BringupCheck {
  const BringupCheck({
    required this.id,
    required this.status,
    required this.measured,
    required this.expected,
    required this.source,
    required this.note,
  });

  final String id;

  /// Server status verbatim: pass, fail, warn, manual, unknown or a newer one.
  final String status;

  /// The server's measured value as decoded JSON; never re-derived here.
  final Object? measured;

  final String expected;
  final String source;
  final String note;

  factory BringupCheck.fromJson(Object? json, String field) {
    final map = _asObject(json, field);
    if (!map.containsKey('measured')) {
      throw FormatException('$field.measured is missing');
    }
    return BringupCheck(
      id: _asString(map, 'id', field),
      status: _asString(map, 'status', field),
      measured: _asJsonValue(map['measured'], '$field.measured'),
      expected: _asString(map, 'expected', field, allowEmpty: true),
      source: _asString(map, 'source', field, allowEmpty: true),
      note: _asString(map, 'note', field, allowEmpty: true),
    );
  }
}

/// One bring-up gate answer from `GET /sessions/{id}/bringup`.
class BringupResult {
  const BringupResult({
    required this.sessionId,
    required this.gate,
    required this.verdict,
    required this.checks,
    required this.needsYou,
    required this.warnings,
  });

  /// The gate and verdict are shown exactly as the server sent them.
  final String sessionId;
  final String gate;
  final String verdict;

  /// Checks in the server's order; a newer status string is kept verbatim.
  final List<BringupCheck> checks;

  /// Ids of manual checks the user still has to judge at the bike.
  final List<String> needsYou;

  /// Ids of checks with status `warn`.
  final List<String> warnings;

  factory BringupResult.fromJson(Object? json) {
    final map = _asObject(json, 'bringup');
    return BringupResult(
      sessionId: _asString(map, 'session_id', 'bringup'),
      gate: _asString(map, 'gate', 'bringup'),
      verdict: _asString(map, 'verdict', 'bringup'),
      checks: _asList(map['checks'], 'bringup.checks')
          .asMap()
          .entries
          .map((entry) => BringupCheck.fromJson(
              entry.value, 'bringup.checks[${entry.key}]'))
          .toList(growable: false),
      needsYou: _asStringList(map['needs_you'], 'bringup.needs_you'),
      warnings: _asStringList(map['warnings'], 'bringup.warnings'),
    );
  }
}

Map<String, Object?> _asObject(Object? value, String field) {
  if (value is! Map) throw FormatException('$field is not an object');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$field has a non-string key');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _asList(Object? value, String field) {
  if (value is! List) throw FormatException('$field is not a list');
  return List<Object?>.from(value);
}

String _asString(Map<String, Object?> map, String key, String field,
    {bool allowEmpty = false}) {
  final value = map[key];
  if (value is! String || (!allowEmpty && value.isEmpty)) {
    throw FormatException('$field.$key is missing or not a string');
  }
  return value;
}

List<String> _asStringList(Object? value, String field) {
  if (value is! List) throw FormatException('$field is not a list');
  return value.asMap().entries.map((entry) {
    if (entry.value is! String) {
      throw FormatException('$field[${entry.key}] is not a string');
    }
    return entry.value as String;
  }).toList(growable: false);
}

Object? _asJsonValue(Object? value, String field) {
  if (value == null || value is String || value is bool) return value;
  if (value is num) {
    if (value is double && !value.isFinite) {
      throw FormatException('$field is not a finite number');
    }
    return value;
  }
  if (value is List) {
    return value
        .asMap()
        .entries
        .map((entry) => _asJsonValue(entry.value, '$field[${entry.key}]'))
        .toList(growable: false);
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('$field has a non-string key');
      }
      result[entry.key as String] =
          _asJsonValue(entry.value, '$field.${entry.key}');
    }
    return result;
  }
  throw FormatException('$field is not a JSON value');
}
