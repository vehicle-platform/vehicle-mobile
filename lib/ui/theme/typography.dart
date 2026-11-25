
import 'package:flutter/material.dart';

import 'package:vehicle_mobile/ui/theme/tokens.dart';

/// Font families bundled under `assets/fonts/` (SIL OFL, D-130 item 1).
abstract final class VehicleFonts {
  /// Modern grotesk for text (variable weight axis).
  static const String text = 'InstrumentSans';

  /// Semi-condensed face with tabular figures for numbers and readouts.
  static const String numbers = 'BarlowSemiCondensed';
}

const List<FontFeature> _tabular = <FontFeature>[FontFeature.tabularFigures()];

/// A text-face style: [weight] drives both the font weight and the variable
/// `wght` axis of Instrument Sans.
TextStyle textFace(double size, FontWeight weight,
        {Color? color, double? height, double? letterSpacing}) =>
    TextStyle(
      fontFamily: VehicleFonts.text,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

/// A number-face style (tabular figures so a changing value does not jitter).
TextStyle numberFace(double size, FontWeight weight,
        {Color? color, double? height, double? letterSpacing}) =>
    TextStyle(
      fontFamily: VehicleFonts.numbers,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: _tabular,
    );

/// The text theme of the app: grotesk for text, the semi-condensed face for
/// every display/headline style (the numerals).
TextTheme buildTextTheme(VehicleTokens t) {
  return TextTheme(
    // Hero numerals (speed).
    displayLarge: numberFace(104, FontWeight.w600,
        color: t.textPrimary, height: 1.0, letterSpacing: -1),
    // Large numerals (RPM, throttle).
    displayMedium: numberFace(56, FontWeight.w600,
        color: t.textPrimary, height: 1.05, letterSpacing: -0.5),
    // Tile numerals (coolant, battery).
    displaySmall:
        numberFace(36, FontWeight.w600, color: t.textPrimary, height: 1.1),
    headlineMedium: textFace(26, FontWeight.w600, color: t.textPrimary),
    headlineSmall: textFace(22, FontWeight.w600, color: t.textPrimary),
    titleLarge: textFace(22, FontWeight.w600, color: t.textPrimary),
    titleMedium: textFace(17, FontWeight.w600, color: t.textPrimary),
    titleSmall: textFace(15, FontWeight.w600, color: t.textPrimary),
    bodyLarge:
        textFace(16, FontWeight.w400, color: t.textPrimary, height: 1.4),
    bodyMedium:
        textFace(14, FontWeight.w400, color: t.textPrimary, height: 1.4),
    bodySmall:
        textFace(12.5, FontWeight.w400, color: t.textSecondary, height: 1.35),
    labelLarge: textFace(15, FontWeight.w600,
        color: t.textPrimary, letterSpacing: 0.2),
    labelMedium: textFace(13, FontWeight.w500,
        color: t.textSecondary, letterSpacing: 0.3),
    // Upper-case, letter-spaced section captions.
    labelSmall: textFace(11.5, FontWeight.w600,
        color: t.textSecondary, letterSpacing: 1.3),
  );
}
