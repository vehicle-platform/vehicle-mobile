import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_mobile/models/ride_summary.dart';
import 'package:vehicle_mobile/ui/rides/ride_format.dart';

void main() {
  group('precision and values', () {
    test('derives precision from the range only', () {
      expect(precisionForRange(0, 2000), 1);
      expect(precisionForRange(0, 200), 2);
      expect(precisionForRange(0, 1), 4);
      expect(precisionForRange(5, 5), 3);
      expect(precisionForRange(-100, -50), 3);
      expect(formatRideValue(12.345, 0, 200), '12.35');
      expect(formatRideValue(null, 0, 200), '–');
      expect(formatRideValue(double.nan, 0, 200), '–');
      expect(formatRideRangeValue(42, const RideRange(0, 86400)), '42');
    });

    test('derives edge precision from the axis range, not the signal range', () {
      const rpm = [
        RideRange(0, 3000),
        RideRange(3000, 6000),
        RideRange(6000, 9000),
        RideRange(9000, 12000),
      ];
      final rpmRange = rideAxisRange(rpm);
      expect(rpmRange.min, 0);
      expect(rpmRange.max, 12000);
      expect(precisionForRange(rpmRange.min, rpmRange.max), 0);

      final subUnit = rideAxisRange(const [RideRange(0, 0.25), RideRange(0.25, 0.5), RideRange(0.5, 1)]);
      expect(precisionForRange(subUnit.min, subUnit.max), 4);

      final single = rideAxisRange(const [RideRange(-10, 10)]);
      expect(precisionForRange(single.min, single.max), 3);

      final negative = rideAxisRange(const [RideRange(-1000, -500), RideRange(-500, 0)]);
      expect(precisionForRange(negative.min, negative.max), 1);

      final empty = rideAxisRange(const []);
      expect(precisionForRange(empty.min, empty.max), 3);
    });

    test('is exact at powers of ten like the analyzer (Math.log10)', () {
      // log(1000) / ln10 is 2.9999999999999996 in doubles; floor must still be 3.
      expect(precisionForRange(0, 10), 3);
      expect(precisionForRange(0, 100), 2);
      expect(precisionForRange(0, 1000), 1);
      expect(precisionForRange(0, 0.001), 6);
      expect(precisionForRange(0, 999.9999), 2);
    });
  });

  group('durations', () {
    test('formats seconds, minutes and hours without a locale', () {
      expect(formatDurationS(0), '0 s');
      expect(formatDurationS(42), '42 s');
      expect(formatDurationS(185), '3 min 05 s');
      expect(formatDurationS(3720), '1 h 02 min');
      expect(formatDurationS(null), '–');
      expect(formatDurationS(-1), '–');
    });
  });

  group('UTC timestamps', () {
    test('always prints UTC with minutes', () {
      expect(formatUtc(DateTime.utc(2026, 1, 15, 12, 5)), '2026-01-15 12:05 UTC');
      expect(formatUtc(DateTime.parse('2026-01-15T15:05:00+03:00')), '2026-01-15 12:05 UTC');
    });
  });

  group('chart helpers', () {
    test('scales bars to the largest value and keeps nulls empty', () {
      expect(barHeights([2, null, 4], 40), [20, 0, 40]);
      expect(barHeights([null, null], 40), [0, 0]);
      expect(barHeights([], 40), isEmpty);
      expect(barHeights([1, 2], 0), [0, 0]);
      expect(maxBarValue([null, -1, 3]), 3);
    });

    test('scales heat opacity like the analyzer', () {
      expect(heatOpacity(null, 12), 0);
      expect(heatOpacity(0, 12), 0);
      expect(heatOpacity(6, 12), closeTo(0.575, 1e-9));
      expect(heatOpacity(12, 12), 1);
      expect(maxCellValue(const [RideCell(index: 0, axes: [0], value: 3, flag: null)]), 3);
    });
  });
}
