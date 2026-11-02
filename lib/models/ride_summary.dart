/// One column of GET /rides. Names and units come from the response.
class RideColumn {
  const RideColumn({required this.name, required this.unit});

  final String name;
  final String unit;

  factory RideColumn.fromJson(Object? json, String field) {
    final map = _asObject(json, field);
    return RideColumn(
      name: _asString(map, 'name', field),
      unit: _asString(map, 'unit', field, allowEmpty: true),
    );
  }
}

/// One session row of GET /rides.
class RideRow {
  const RideRow({
    required this.sessionId,
    required this.createdUtc,
    required this.values,
    required this.flags,
  });

  final String sessionId;
  final DateTime? createdUtc;
  final Map<String, double?> values;
  final Map<String, String?> flags;

  factory RideRow.fromJson(Object? json, String field, List<RideColumn> columns) {
    final map = _asObject(json, field);
    final values = _asObject(map['values'], '$field.values');
    final flags = _asObject(map['flags'], '$field.flags');
    final parsedValues = <String, double?>{};
    final parsedFlags = <String, String?>{};
    for (final column in columns) {
      parsedValues[column.name] = _asNullableDouble(values[column.name], '$field.values.${column.name}');
      parsedFlags[column.name] = _asNullableString(flags[column.name], '$field.flags.${column.name}');
    }
    return RideRow(
      sessionId: _asString(map, 'session_id', field),
      createdUtc: _asNullableUtc(map['created_utc'], '$field.created_utc'),
      values: parsedValues,
      flags: parsedFlags,
    );
  }
}

/// GET /rides: one row per session that has a stored ride summary.
class RidesTable {
  const RidesTable({required this.columns, required this.rows, required this.skipped});

  final List<RideColumn> columns;
  final List<RideRow> rows;

  /// Sessions inside the requested range without a usable stored summary.
  final int skipped;

  factory RidesTable.fromJson(Object? json) {
    final map = _asObject(json, 'rides');
    final columns = _asList(map['columns'], 'rides.columns')
        .asMap()
        .entries
        .map((entry) => RideColumn.fromJson(entry.value, 'rides.columns[${entry.key}]'))
        .toList(growable: false);
    final seen = <String>{};
    for (final column in columns) {
      if (!seen.add(column.name)) {
        throw FormatException('rides.columns has a duplicate name: ${column.name}');
      }
    }
    final rows = _asList(map['rows'], 'rides.rows')
        .asMap()
        .entries
        .map((entry) => RideRow.fromJson(entry.value, 'rides.rows[${entry.key}]', columns))
        .toList(growable: false);
    final skipped = _asInt(map, 'skipped', 'rides');
    if (skipped < 0) throw const FormatException('rides.skipped is negative');
    return RidesTable(columns: columns, rows: rows, skipped: skipped);
  }
}

/// Inclusive [min, max] range of one summary signal, from the response.
class RideRange {
  const RideRange(this.min, this.max);

  final double min;
  final double max;
}

class RideAxis {
  const RideAxis({required this.input, required this.unit, required this.edges});

  final String input;
  final String unit;
  final List<RideRange> edges;

  factory RideAxis.fromJson(Object? json, String field) {
    final map = _asObject(json, field);
    final edges = _asList(map['edges'], '$field.edges')
        .asMap()
        .entries
        .map((entry) => _asRange(entry.value, '$field.edges[${entry.key}]'))
        .toList(growable: false);
    return RideAxis(
      input: _asString(map, 'input', field),
      unit: _asString(map, 'unit', field, allowEmpty: true),
      edges: edges,
    );
  }
}

class RideCell {
  const RideCell({required this.index, required this.axes, required this.value, required this.flag});

  final int index;
  final List<int> axes;
  final double? value;
  final String? flag;

  factory RideCell.fromJson(Object? json, String field) {
    final map = _asObject(json, field);
    return RideCell(
      index: _asInt(map, 'index', field),
      axes: _asList(map['axes'], '$field.axes')
          .asMap()
          .entries
          .map((entry) => _asIntValue(entry.value, '$field.axes[${entry.key}]'))
          .toList(growable: false),
      value: _asNullableDouble(map['value'], '$field.value'),
      flag: _asNullableString(map['flag'], '$field.flag'),
    );
  }
}

/// One entry of `/sessions/{id}/summary` `signals`.
sealed class RideSummarySignal {
  const RideSummarySignal({required this.name, required this.status});

  final String name;
  final String status;
}

class ScalarSummary extends RideSummarySignal {
  const ScalarSummary({
    required super.name,
    required super.status,
    required this.unit,
    required this.range,
    required this.value,
    required this.flag,
  });

  final String unit;
  final RideRange range;
  final double? value;
  final String? flag;

  factory ScalarSummary.fromJson(Map<String, Object?> map, String field) {
    return ScalarSummary(
      name: _asString(map, 'name', field),
      status: _asString(map, 'status', field),
      unit: _asString(map, 'unit', field, allowEmpty: true),
      range: _asRange(map['range'], '$field.range'),
      value: _asNullableDouble(map['value'], '$field.value'),
      flag: _asNullableString(map['flag'], '$field.flag'),
    );
  }
}

class BinnedSummary extends RideSummarySignal {
  const BinnedSummary({
    required super.name,
    required super.status,
    required this.unit,
    required this.range,
    required this.axes,
    required this.cells,
    required this.totalS,
    required this.outsideS,
    required this.defsMismatch,
  });

  final String unit;
  final RideRange range;
  final List<RideAxis> axes;
  final List<RideCell> cells;
  final double totalS;
  final double outsideS;
  final bool defsMismatch;

  factory BinnedSummary.fromJson(Map<String, Object?> map, String field) {
    final axes = _asList(map['axes'], '$field.axes')
        .asMap()
        .entries
        .map((entry) => RideAxis.fromJson(entry.value, '$field.axes[${entry.key}]'))
        .toList(growable: false);
    if (axes.isEmpty) {
      throw FormatException('$field.axes is empty');
    }
    final cells = _asList(map['cells'], '$field.cells')
        .asMap()
        .entries
        .map((entry) => RideCell.fromJson(entry.value, '$field.cells[${entry.key}]'))
        .toList(growable: false);
    return BinnedSummary(
      name: _asString(map, 'name', field),
      status: _asString(map, 'status', field),
      unit: _asString(map, 'unit', field, allowEmpty: true),
      range: _asRange(map['range'], '$field.range'),
      axes: axes,
      cells: cells,
      totalS: _asDouble(map['total_s'], '$field.total_s'),
      outsideS: _asDouble(map['outside_s'], '$field.outside_s'),
      defsMismatch: _asOptionalBool(map, 'defs_mismatch', field) ?? false,
    );
  }
}

class UnavailableSummary extends RideSummarySignal {
  const UnavailableSummary({
    required super.name,
    required super.status,
    required this.reason,
    required this.pendingInputs,
    required this.missing,
    required this.message,
  });

  final String? reason;
  final List<String> pendingInputs;
  final List<String> missing;
  final String? message;

  factory UnavailableSummary.fromJson(Map<String, Object?> map, String field) {
    return UnavailableSummary(
      name: _asString(map, 'name', field),
      status: _asString(map, 'status', field),
      reason: _asNullableString(map['reason'], '$field.reason'),
      pendingInputs: _asStringList(map['pending_inputs'], '$field.pending_inputs'),
      missing: _asStringList(map['missing'], '$field.missing'),
      message: _asNullableString(map['message'], '$field.message'),
    );
  }
}

/// GET /sessions/{id}/summary for one session.
class RideSummary {
  const RideSummary({
    required this.sessionId,
    required this.rideDefinition,
    required this.defsVersion,
    required this.signals,
  });

  final String sessionId;
  final String? rideDefinition;
  final String? defsVersion;
  final List<RideSummarySignal> signals;

  factory RideSummary.fromJson(Object? json) {
    final map = _asObject(json, 'summary');
    return RideSummary(
      sessionId: _asString(map, 'session_id', 'summary'),
      rideDefinition: _asNullableString(map['ride_definition'], 'summary.ride_definition'),
      defsVersion: _asNullableString(map['defs_version'], 'summary.defs_version'),
      signals: _asList(map['signals'], 'summary.signals')
          .asMap()
          .entries
          .map((entry) => _parseSignal(entry.value, 'summary.signals[${entry.key}]'))
          .toList(growable: false),
    );
  }
}

RideSummarySignal _parseSignal(Object? json, String field) {
  final map = _asObject(json, field);
  final status = _asString(map, 'status', field);
  if (status != 'computed') {
    return UnavailableSummary.fromJson(map, field);
  }
  final kind = _asString(map, 'kind', field);
  return switch (kind) {
    'scalar' => ScalarSummary.fromJson(map, field),
    'binned' => BinnedSummary.fromJson(map, field),
    _ => throw FormatException('$field.kind is unknown: $kind'),
  };
}

Map<String, Object?> _asObject(Object? value, String field) {
  if (value is! Map) throw FormatException('$field is not an object');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw FormatException('$field has a non-string key');
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _asList(Object? value, String field) {
  if (value is! List) throw FormatException('$field is not a list');
  return List<Object?>.from(value);
}

String _asString(Map<String, Object?> map, String key, String field, {bool allowEmpty = false}) {
  final value = map[key];
  if (value is! String || (!allowEmpty && value.isEmpty)) {
    throw FormatException('$field.$key is missing or not a string');
  }
  return value;
}

String? _asNullableString(Object? value, String field) {
  if (value == null) return null;
  if (value is! String) throw FormatException('$field is not a string');
  return value;
}

double _asDouble(Object? value, String field) {
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$field is missing or not a finite number');
}

double? _asNullableDouble(Object? value, String field) {
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$field is not null or a finite number');
}

int _asIntValue(Object? value, String field) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) return value.toInt();
  throw FormatException('$field is not an integer');
}

int _asInt(Map<String, Object?> map, String key, String field) {
  final value = map[key];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) return value.toInt();
  throw FormatException('$field.$key is missing or not an integer');
}

bool? _asOptionalBool(Map<String, Object?> map, String key, String field) {
  final value = map[key];
  if (value == null) return null;
  if (value is! bool) throw FormatException('$field.$key is not a boolean');
  return value;
}

RideRange _asRange(Object? value, String field) {
  final list = _asList(value, field);
  if (list.length != 2) throw FormatException('$field is not [min, max]');
  return RideRange(_asDouble(list[0], '$field[0]'), _asDouble(list[1], '$field[1]'));
}

List<String> _asStringList(Object? value, String field) {
  if (value == null) return const [];
  if (value is! List) throw FormatException('$field is not a list');
  return value
      .asMap()
      .entries
      .map((entry) => _asStringValue(entry.value, '$field[${entry.key}]'))
      .toList(growable: false);
}

String _asStringValue(Object? value, String field) {
  if (value is! String) throw FormatException('$field is not a string');
  return value;
}

DateTime? _asNullableUtc(Object? value, String field) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) throw FormatException('$field is not an ISO 8601 timestamp');
  final hasZone = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(value);
  final parsed = DateTime.tryParse(hasZone ? value : '${value}Z');
  if (parsed == null) throw FormatException('$field is not an ISO 8601 timestamp');
  return parsed.toUtc();
}

