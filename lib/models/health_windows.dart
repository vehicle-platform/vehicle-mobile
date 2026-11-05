/// D-079 health-window instances from `report.derived_summary.health_windows`.
///
/// This only parses what vehicle-server stored: window keys, times, reasons and counts stay
/// verbatim. It never recomputes a window and never guesses a missing field.
class HealthWindowInstance {
  const HealthWindowInstance({
    required this.startMs,
    required this.endMs,
    required this.durationMs,
    required this.closeReason,
    required this.qualifies,
    required this.firstQualifying,
  });

  final int startMs;
  final int endMs;
  final int durationMs;
  final String closeReason;
  final bool qualifies;
  final bool firstQualifying;

  factory HealthWindowInstance.fromJson(Object? json, String field) {
    final map = _asObject(json, field);
    final start = _asInt(map, 'start_ms', field);
    final end = _asInt(map, 'end_ms', field);
    final duration = _asInt(map, 'duration_ms', field);
    if (end < start) {
      throw FormatException('$field.end_ms is before start_ms');
    }
    if (duration != end - start) {
      throw FormatException(
          '$field.duration_ms does not match end_ms - start_ms');
    }
    return HealthWindowInstance(
      startMs: start,
      endMs: end,
      durationMs: duration,
      closeReason: _asString(map, 'close_reason', field),
      qualifies: _asBool(map, 'qualifies', field),
      firstQualifying: _asBool(map, 'first_qualifying', field),
    );
  }
}

class HealthWindowInstances {
  const HealthWindowInstances({
    required this.key,
    required this.qualifyingCount,
    required this.instances,
  });

  final String key;
  final int qualifyingCount;
  final List<HealthWindowInstance> instances;

  factory HealthWindowInstances.fromJson(
      String key, Object? json, String field) {
    final map = _asObject(json, field);
    final count = _asInt(map, 'qualifying_count', field);
    if (count < 0) {
      throw FormatException('$field.qualifying_count is negative');
    }
    var firstQualifyingCount = 0;
    final instances = _asList(map['instances'], '$field.instances')
        .asMap()
        .entries
        .map((entry) {
      final instance = HealthWindowInstance.fromJson(
        entry.value,
        '$field.instances[${entry.key}]',
      );
      if (instance.firstQualifying) firstQualifyingCount++;
      return instance;
    }).toList(growable: false);
    if (firstQualifyingCount > 1) {
      throw FormatException(
          '$field has more than one first_qualifying instance');
    }
    return HealthWindowInstances(
        key: key, qualifyingCount: count, instances: instances);
  }
}

class HealthWindows {
  const HealthWindows({
    required this.rule,
    required this.t0DeviceMs,
    required this.windows,
  });

  final String rule;
  final int t0DeviceMs;
  final List<HealthWindowInstances> windows;
}

/// Parsed block, or the reason it cannot be shown (never a guessed block).
class HealthWindowsResult {
  const HealthWindowsResult.ok(HealthWindows this.block) : reason = null;

  const HealthWindowsResult.unavailable(String this.reason) : block = null;

  final HealthWindows? block;
  final String? reason;

  bool get isOk => block != null;
}

/// Parses `report["derived_summary"]["health_windows"]` in the response order.
HealthWindowsResult parseHealthWindows(Object? report) {
  if (report is! Map) {
    return const HealthWindowsResult.unavailable(
        'malformed: report is not an object');
  }
  final reportMap = _asObject(report, 'report');
  if (!reportMap.containsKey('derived_summary')) {
    return const HealthWindowsResult.unavailable('not in report');
  }
  final derived = reportMap['derived_summary'];
  if (derived is! Map) {
    return const HealthWindowsResult.unavailable(
        'malformed: derived_summary is not an object');
  }
  final derivedMap = _asObject(derived, 'derived_summary');
  if (!derivedMap.containsKey('health_windows')) {
    return const HealthWindowsResult.unavailable('not in report');
  }
  final block = derivedMap['health_windows'];
  if (block is! Map) {
    return const HealthWindowsResult.unavailable(
      'malformed: derived_summary.health_windows is not an object',
    );
  }
  final blockMap = _asObject(block, 'derived_summary.health_windows');
  try {
    final rule = _asString(blockMap, 'rule', 'derived_summary.health_windows');
    final t0 =
        _asInt(blockMap, 't0_device_ms', 'derived_summary.health_windows');
    final windowsMap = _asObject(
      blockMap['windows'],
      'derived_summary.health_windows.windows',
    );
    final windows = windowsMap.entries
        .map((entry) => HealthWindowInstances.fromJson(
              entry.key,
              entry.value,
              'derived_summary.health_windows.windows.${entry.key}',
            ))
        .toList(growable: false);
    return HealthWindowsResult.ok(
      HealthWindows(rule: rule, t0DeviceMs: t0, windows: windows),
    );
  } on FormatException catch (error) {
    return HealthWindowsResult.unavailable('malformed: ${error.message}');
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

String _asString(Map<String, Object?> map, String key, String field) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$field.$key is missing or not a string');
  }
  return value;
}

int _asInt(Map<String, Object?> map, String key, String field) {
  final value = map[key];
  // jsonDecode yields `int` for 5 and `double` for 5.0; only the former is an integer time.
  if (value is int) return value;
  throw FormatException('$field.$key is missing or not an integer');
}

bool _asBool(Map<String, Object?> map, String key, String field) {
  final value = map[key];
  if (value is! bool) {
    throw FormatException('$field.$key is missing or not a boolean');
  }
  return value;
}
