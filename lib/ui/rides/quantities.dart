import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/l10n/rider_format.dart';


/// Rider-meaningful quantities (D-130 follow-up): the ones the Logbook list and
/// the assistant data cards show first, in this order. Everything else is an
/// engineering signal that stays under "All signals" / the raw expander.
const List<String> riderQuantityOrder = [
  'ride_distance',
  'ride_time',
  'ride_stop_count',
  'ride_idle_time',
  'ride_warmup_time',
  'ride_end_coolant_temp',
  'ride_start_coolant_temp',
  'ride_fuel_consumption',
  'ride_fuel_used',
  'ride_rest_voltage',
  'ride_shift_count',
  'ride_aggressiveness_score',
];

/// Columns every Logbook row shows.
const List<String> logbookBaseColumns = [
  'ride_distance',
  'ride_time',
  'ride_stop_count',
  'ride_idle_time',
];

bool isRiderQuantity(String name) => riderQuantityOrder.contains(name);

/// ARB label of a known quantity, or null.
String? quantityLabel(AppLocalizations l, String name) => switch (name) {
      'ride_distance' => l.quantityRideDistance,
      'ride_time' => l.quantityRideTime,
      'ride_stop_count' => l.quantityRideStopCount,
      'ride_idle_time' => l.quantityRideIdleTime,
      'ride_warmup_time' => l.quantityRideWarmupTime,
      'ride_end_coolant_temp' => l.quantityRideEndCoolantTemp,
      'ride_start_coolant_temp' => l.quantityRideStartCoolantTemp,
      'ride_fuel_consumption' => l.quantityRideFuelConsumption,
      'ride_fuel_used' => l.quantityRideFuelUsed,
      'ride_rest_voltage' => l.quantityRideRestVoltage,
      'ride_shift_count' => l.quantityRideShiftCount,
      'ride_aggressiveness_score' => l.quantityRideAggressiveness,
      _ => null,
    };

/// A readable label derived from an internal name when no ARB label exists:
/// `ride_ltft_mean` -> "Ltft mean".
String readableName(String name) {
  var text = name;
  for (final prefix in const ['ride_', 'window_', 'did.', 'sensor.']) {
    if (text.startsWith(prefix)) text = text.substring(prefix.length);
  }
  text = text.replaceAll(RegExp(r'[_.]+'), ' ').trim();
  if (text.isEmpty) return name;
  return text[0].toUpperCase() + text.substring(1);
}

/// ARB label, else [serverLabel] (capitalised), else the derived name.
String quantityText(AppLocalizations l, String name, {String? serverLabel}) {
  final known = quantityLabel(l, name);
  if (known != null) return known;
  if (serverLabel != null && serverLabel.trim().isNotEmpty) {
    final s = serverLabel.trim();
    return s[0].toUpperCase() + s.substring(1);
  }
  return readableName(name);
}

/// One value of a data card.
class ChatDatum {
  const ChatDatum({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;
}

const Set<String> _listKeys = {'signals', 'values', 'ride_values', 'items'};

/// Data-card values of a tool [result] (D-130 item 3): labelled numeric
/// quantities only. Ids, versions, statuses, list indices and internal names
/// are never values. Lists of `{name, unit, value[, label]}` items (ride
/// signals, signal stats) contribute the computed scalar ones, rider-meaningful
/// first; plain numeric fields of the result map contribute too, unless their
/// key names an id/version/status. At most [max] values.
List<ChatDatum> chatData(Object? result, AppLocalizations l, {int max = 6}) {
  final items = <_Item>[];
  void collectList(List<Object?> list) {
    for (final e in list) {
      if (e is! Map) continue;
      final name = e['name'];
      final value = e['value'];
      final status = e['status'];
      if (name is! String || value is! num || !value.isFinite) continue;
      if (status != null && status != 'ok' && status != 'computed') continue;
      final kind = e['kind'];
      if (kind != null && kind != 'scalar') continue;
      items.add(_Item(
        name: name,
        value: value,
        unit: e['unit'] is String ? e['unit'] as String : null,
        label: e['label'] is String ? e['label'] as String : null,
      ));
    }
  }

  void walk(Map<Object?, Object?> map, int depth) {
    for (final entry in map.entries) {
      final key = '${entry.key}';
      final v = entry.value;
      if (v is List && _listKeys.contains(key)) {
        collectList(v.cast<Object?>());
      } else if (v is Map && depth < 2 && !_internalKey(key)) {
        walk(v.cast<Object?, Object?>(), depth + 1);
      } else if (v is num && v.isFinite && !_internalKey(key)) {
        final unit = _unitOfKey(key);
        items.add(_Item(
            name: unit == null ? key : key.substring(0, key.lastIndexOf('_')),
            value: v,
            unit: unit,
            label: null));
      }
    }
  }

  if (result is Map) walk(result.cast<Object?, Object?>(), 0);
  // Rider-meaningful first (in the defined order), then the stats-style
  // min/average/max items, then the rest in server order.
  int rank(_Item i) {
    final r = riderQuantityOrder.indexOf(i.name);
    if (r >= 0) return r;
    if (RegExp(r'_(min|mean|avg|average|max)$').hasMatch(i.name)) {
      return riderQuantityOrder.length;
    }
    return riderQuantityOrder.length + 1;
  }

  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final c = rank(a.$2).compareTo(rank(b.$2));
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  // A ride result with many engineering signals shows only the rider ones.
  final hasRider = indexed.any((e) => isRiderQuantity(e.$2.name));
  final picked = [
    for (final e in indexed)
      if (!hasRider || isRiderQuantity(e.$2.name)) e.$2,
  ].take(max);
  final fmt = RiderFormat(l);
  return [
    for (final i in picked)
      ChatDatum(
        label: quantityText(l, i.name, serverLabel: i.label),
        value: fmt.value(i.value, i.unit),
        unit: fmt.unit(i.unit),
      ),
  ];
}

class _Item {
  const _Item(
      {required this.name,
      required this.value,
      required this.unit,
      required this.label});

  final String name;
  final num value;
  final String? unit;
  final String? label;
}

bool _internalKey(String key) {
  final k = key.toLowerCase();
  return k == 'id' ||
      k.endsWith('_id') ||
      k.contains('version') ||
      k.contains('status') ||
      k.contains('index');
}

const Map<String, String> _keyUnitSuffixes = {
  'kmh': 'km/h',
  'km': 'km',
  'rpm': 'rpm',
  'pct': '%',
  'kpa': 'kPa',
  'min': 'min',
  'ms': 'ms',
  'c': '°C',
  'v': 'V',
  's': 's',
};

String? _unitOfKey(String key) {
  final cut = key.lastIndexOf('_');
  if (cut <= 0) return null;
  return _keyUnitSuffixes[key.substring(cut + 1).toLowerCase()];
}
