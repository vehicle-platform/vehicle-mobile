import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/l10n/rider_format.dart';

RiderFormat _fmt(String lang, DateTime now) =>
    RiderFormat(lookupAppLocalizations(Locale(lang)), now: () => now);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('tr');
  });

  final now = DateTime(2026, 11, 26, 12, 0);

  group('numbers by unit', () {
    test('distances and voltages one decimal, speeds and temperatures integers',
        () {
      final f = _fmt('en', now);
      expect(f.value(11.0, 'km'), '11.0');
      expect(f.value(20.645805, 'km'), '20.6');
      expect(f.value(12.64, 'V'), '12.6');
      expect(f.value(98.4, 'km/h'), '98');
      expect(f.value(90.0, 'degC'), '90');
      expect(f.value(3012.7, 'rpm'), '3,013');
      expect(f.value(2.0, 'count'), '2');
      expect(f.value(null, 'km'), '–');
    });

    test('Turkish uses the decimal comma', () {
      final f = _fmt('tr', now);
      expect(f.value(11.0, 'km'), '11,0');
      expect(f.value(12.64, 'V'), '12,6');
      expect(f.withUnit(11.0, 'km'), '11,0 km');
      expect(f.withUnit(90.0, 'degC'), '90 °C');
    });

    test('durations and units', () {
      final f = _fmt('en', now);
      expect(f.value(1215, 's'), '20 min 15 s');
      expect(f.duration(42), '42 s');
      expect(f.duration(3720), '1 h 02 min');
      expect(f.duration(-1), '–');
      expect(f.unit('s'), isNull);
      expect(f.unit('count'), isNull);
      expect(f.unit('degC'), '°C');
    });
  });

  group('dates', () {
    test('weekday, day and month with the time, never UTC', () {
      final f = _fmt('en', now);
      expect(f.dateTime(DateTime(2026, 11, 18, 9, 0)), 'Wed 18 Nov · 09:00');
      expect(f.dateTime(DateTime(2026, 11, 18, 9, 0)), isNot(contains('UTC')));
      expect(_fmt('tr', now).dateTime(DateTime(2026, 11, 18, 9, 0)),
          'Çar 18 Kas · 09:00');
    });

    test('Today and Yesterday for recent days', () {
      final f = _fmt('en', now);
      expect(f.dateTime(DateTime(2026, 11, 26, 9, 0)), 'Today · 09:00');
      expect(f.dateTime(DateTime(2026, 11, 25, 22, 30)),
          'Yesterday · 22:30');
      final tr = _fmt('tr', now);
      expect(tr.day(DateTime(2026, 11, 26, 1)), 'Bugün');
      expect(tr.day(DateTime(2026, 11, 25, 1)), 'Dün');
    });

    test('UTC instants are shown in local time', () {
      final f = _fmt('en', now);
      final utc = DateTime.utc(2026, 11, 18, 9, 0);
      expect(f.time(utc), f.time(utc.toLocal()));
    });
  });
}
