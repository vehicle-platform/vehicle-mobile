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
  const aaa = 7.0;
  final themes = {
    'dark': VehicleTokens.dark,
    'light': VehicleTokens.light,
    'sunlight': VehicleTokens.sunlight,
  };

  for (final entry in themes.entries) {
    final t = entry.value;
    // Sunlight must stay readable under glare: AAA for every text and state
    // colour, and borders that read as lines, not as a faint tint.
    final target = entry.key == 'sunlight' ? aaa : aa;
    final level = target == aaa ? 'AAA' : 'AA';
    group('WCAG $level text contrast, ${entry.key} theme', () {
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
            expect(contrast(text.value, surface.value),
                greaterThanOrEqualTo(target));
          });
        }
      }
      test('onAccent on accent', () {
        expect(contrast(t.onAccent, t.accent), greaterThanOrEqualTo(target));
      });
      test('hairline stays visible but is not a text colour', () {
        expect(contrast(t.hairline, t.background), greaterThan(1.1));
      });
    });
  }

  test('sunlight borders read under glare (>= 4.5:1 on every surface)', () {
    const t = VehicleTokens.sunlight;
    for (final surface in [t.background, t.surface, t.surfaceRaised]) {
      expect(contrast(t.outline, surface), greaterThanOrEqualTo(4.5));
    }
  });

  test('sunlight theme draws 2 px borders, the others 1 px', () {
    final sun = buildAppTheme(brightness: Brightness.light, sunlight: true);
    final light = buildAppTheme(brightness: Brightness.light);
    final dark =
        buildAppTheme(sunlight: true); // sunlight only applies to light
    expect(sun.dividerTheme.thickness, 2);
    expect(light.dividerTheme.thickness, 1);
    expect(dark.dividerTheme.thickness, 1);
    expect(sun.extension<VehicleTokens>(), VehicleTokens.sunlight);
    expect(dark.extension<VehicleTokens>(), VehicleTokens.dark);
  });

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
