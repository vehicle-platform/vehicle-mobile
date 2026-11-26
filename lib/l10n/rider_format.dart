import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';

/// Number and date formatting for the rider UI (D-130): one place, keyed by
/// unit and by the active locale. Presentation only; raw values stay in the
/// "computed by" expander and in the data layer.
///
/// Decimals by unit: distances, voltages, fuel and percentages 1 decimal;
/// speeds, temperatures, rpm and counts integers. Dates are local time with
/// weekday ("Wed 26 Nov · 09:00"), "Today" / "Yesterday" for recent days,
/// never "UTC".
class RiderFormat {
  RiderFormat(this.l, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        tag = l.localeName;

  /// The format of the active locale of [context].
  factory RiderFormat.of(BuildContext context, {DateTime Function()? now}) =>
      RiderFormat(context.l10n, now: now);

  final AppLocalizations l;
  final String tag;
  final DateTime Function() _now;

  static const Map<String, int> _decimals = {
    'km': 1,
    'km/h': 0,
    'kmh': 0,
    'm/s': 1,
    'V': 1,
    'degC': 0,
    '°C': 0,
    'rpm': 0,
    '%': 1,
    'L': 1,
    'L/100km': 1,
    'kPa': 0,
    'degC/min': 1,
    'count': 0,
    'flag': 0,
    'ratio': 2,
    'ms': 0,
    'm': 0,
    'm2': 2,
    'N': 0,
  };

  /// Decimals shown for [unit] (one decimal when the unit is unknown).
  static int decimalsFor(String? unit) => _decimals[unit] ?? 1;

  /// [value] with the decimals of [unit] and the locale's decimal separator;
  /// seconds become a duration ("20 min 15 s").
  String value(num? value, String? unit) {
    if (value == null || !value.isFinite) return '–';
    if (unit == 's') return duration(value);
    return number(value, decimalsFor(unit));
  }

  String number(num value, int decimals) {
    try {
      return NumberFormat.decimalPatternDigits(
              locale: tag, decimalDigits: decimals)
          .format(value);
    } catch (_) {
      return value.toStringAsFixed(decimals);
    }
  }

  /// Unit text for display: `degC` -> `°C`; dimensionless units show nothing;
  /// durations (already in the value text) show nothing.
  String? unit(String? unit) {
    if (unit == null) return null;
    return switch (unit) {
      '' || 'count' || 'flag' || 'ratio' || 's' => null,
      'degC' => '°C',
      'degC/min' => '°C/min',
      _ => unit,
    };
  }

  /// `value unit` for display (the unit omitted when it has no text).
  String withUnit(num? v, String? u) {
    final text = value(v, u);
    final shown = unit(u);
    return shown == null ? text : '$text $shown';
  }

  /// Whole seconds in a compact form: `42 s`, `3 min 05 s`, `1 h 02 min`.
  String duration(num seconds) {
    if (!seconds.isFinite || seconds < 0) return '–';
    final total = seconds.round();
    if (total < 60) return '$total s';
    final minutes = total ~/ 60;
    final rest = total % 60;
    if (total < 3600) {
      return '$minutes min ${rest.toString().padLeft(2, '0')} s';
    }
    final hours = total ~/ 3600;
    final hourMinutes = (total % 3600) ~/ 60;
    return '$hours h ${hourMinutes.toString().padLeft(2, '0')} min';
  }

  /// Formats [t] with [pattern] in the active locale; when that locale's date
  /// data is not loaded (a bare widget under test) the always-built-in
  /// en_US data is used.
  String _fmt(String pattern, DateTime t) {
    try {
      return DateFormat(pattern, tag).format(t);
    } catch (_) {
      return DateFormat(pattern, 'en_US').format(t);
    }
  }

  /// `09:00` (24 h, local time).
  String time(DateTime t) => _fmt('HH:mm', t.toLocal());

  /// "Today", "Yesterday" or "Wed 26 Nov" (local day).
  String day(DateTime t) {
    final local = t.toLocal();
    final now = _now().toLocal();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(local.year, local.month, local.day))
        .inDays;
    if (diff == 0) return l.formatToday;
    if (diff == 1) return l.formatYesterday;
    return _fmt('EEE d MMM', local);
  }

  /// "Wed 26 Nov · 09:00", "Today · 09:00" (local time).
  String dateTime(DateTime t) => '${day(t)} · ${time(t)}';
}
