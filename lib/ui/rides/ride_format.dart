import 'dart:math' as math;

import 'package:vehicle_mobile/models/ride_summary.dart';

/// Decimals for a value, derived only from the response range.
int precisionForRange(double min, double max) {
  final span = (max - min).abs();
  if (!span.isFinite || span == 0) return 3;
  return math.min(6, math.max(0, 4 - _floorLog10(span)));
}

/// floor(log10(x)) for x > 0, exact at powers of ten (`log(1000) / ln10` is
/// 2.9999999999999996 in double arithmetic; JS `Math.log10` gives 3).
int _floorLog10(double x) {
  var exponent = (math.log(x) / math.ln10).floor();
  if (math.pow(10, exponent + 1) <= x) exponent++;
  if (math.pow(10, exponent) > x) exponent--;
  return exponent;
}

/// The range of a binned axis: its first edge min .. its last edge max.
RideRange rideAxisRange(List<RideRange> edges) {
  if (edges.isEmpty) return const RideRange(0, 0);
  return RideRange(edges.first.min, edges.last.max);
}

String formatRideValue(double? value, double min, double max) {
  if (value == null || !value.isFinite) return '–';
  return value.toStringAsFixed(precisionForRange(min, max));
}

String formatRideRangeValue(double? value, RideRange range) => formatRideValue(value, range.min, range.max);

/// Heights scaled to the largest positive value; nulls and non-positive
/// values stay empty.
List<double> barHeights(List<double?> values, double height) {
  if (!height.isFinite || height <= 0 || values.isEmpty) {
    return List<double>.filled(values.length, 0);
  }
  final max = maxBarValue(values);
  return values
      .map((value) => value != null && value.isFinite && value > 0 && max > 0 ? (value / max) * height : 0.0)
      .toList(growable: false);
}

double maxBarValue(Iterable<double?> values) {
  var max = 0.0;
  for (final value in values) {
    if (value != null && value.isFinite && value > max) max = value;
  }
  return max;
}

/// 0 for null/zero cells, 0.15..1 for positive values, so the grid stays visible.
double heatOpacity(double? value, double max) {
  if (value == null || !value.isFinite || value <= 0 || !max.isFinite || max <= 0) return 0;
  return 0.15 + 0.85 * math.min(1, value / max);
}

double maxCellValue(Iterable<RideCell> cells) => maxBarValue(cells.map((cell) => cell.value));
