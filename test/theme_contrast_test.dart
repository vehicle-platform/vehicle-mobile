import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// WCAG 2.x contrast ratio of two colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const aa = 4.5;
  final themes = {'dark': VehicleTokens.dark, 'light': VehicleTokens.light};

  for (final entry in themes.entries) {
    final t = entry.value;
    group('WCAG AA text contrast, ${entry.key} theme', () {
      final texts = {
        'textPrimary': t.textPrimary,
        'textSecondary': t.textSecondary,
        'noData': t.noData,
        'notPolled': t.notPolled,
        'accent (live/active)': t.accent,
        'advisory (amber)': t.advisory,
        'critical (red)': t.critical,
        'record': t.record,
      };
      final surfaces = {
        'background': t.background,
        'surface': t.surface,
        'surfaceRaised': t.surfaceRaised,
      };
      for (final text in texts.entries) {
        for (final surface in surfaces.entries) {
          test('${text.key} on ${surface.key}', () {
            expect(contrast(text.value, surface.value), greaterThanOrEqualTo(aa));
          });
        }
      }
      test('onAccent on accent', () {
        expect(contrast(t.onAccent, t.accent), greaterThanOrEqualTo(aa));
      });
      test('hairline stays visible but is not a text colour', () {
        expect(contrast(t.hairline, t.background), greaterThan(1.1));
      });
    });
  }

  test('radii stay at 8 or below and motion within 150-200 ms', () {
    expect(Radii.chip, lessThanOrEqualTo(8));
    expect(Radii.card, lessThanOrEqualTo(8));
    expect(Radii.hero, lessThanOrEqualTo(8));
    expect(Motion.fast.inMilliseconds, 150);
    expect(Motion.standard.inMilliseconds, 200);
  });

  test('the theme uses the bundled text and number faces', () {
    final theme = buildAppTheme();
    expect(theme.textTheme.bodyMedium!.fontFamily, VehicleFonts.text);
    expect(theme.textTheme.displayLarge!.fontFamily, VehicleFonts.numbers);
  });
}
