import 'package:flutter/material.dart';

/// Colour tokens of the app (D-130 item 1). One place; screens read them
/// through `context.vehicle` and never hard-code a colour.
///
/// Colour carries meaning only: one teal [accent] for live/active state,
/// amber [advisory] (D-129 class P2), red [critical] (class P1). Surfaces are
/// graphite in the dark theme and a barely warm off-white in the light theme;
/// no gradients, glows or shadows.
@immutable
class VehicleTokens extends ThemeExtension<VehicleTokens> {
  const VehicleTokens({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.live,
    required this.stale,
    required this.noData,
    required this.notPolled,
    required this.error,
    required this.record,
  });

  /// Screen background.
  final Color background;

  /// Panel / row surface.
  final Color surface;

  /// Raised surface (inputs, chips, selected rows).
  final Color surfaceRaised;

  /// Hairline dividers and borders.
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;

  /// The single accent colour: live/active state, selection, primary actions.
  final Color accent;
  final Color onAccent;

  /// Signal / link states.
  final Color live;
  final Color stale;
  final Color noData;
  final Color notPolled;
  final Color error;

  /// Recording indicator / record action.
  final Color record;

  /// Advisory (D-129 P2): amber.
  Color get advisory => stale;

  /// Critical (D-129 P1): red.
  Color get critical => error;

  /// Hairline divider colour.
  Color get hairline => outline;

  /// Warning tone for caution banners (same hue as [advisory]).
  Color get warning => stale;

  /// Dark graphite (default).
  static const VehicleTokens dark = VehicleTokens(
    background: Color(0xFF0F1114),
    surface: Color(0xFF16191D),
    surfaceRaised: Color(0xFF1E2227),
    outline: Color(0xFF2C3238),
    textPrimary: Color(0xFFEDEFF1),
    textSecondary: Color(0xFFA2AAB2),
    accent: Color(0xFF2DD4BF),
    onAccent: Color(0xFF04201C),
    live: Color(0xFF2DD4BF),
    stale: Color(0xFFF5B83D),
    noData: Color(0xFF8E98A3),
    notPolled: Color(0xFF8F9BB0),
    error: Color(0xFFFF6B6B),
    record: Color(0xFFFF5A5A),
  );

  /// Warm off-white (follows the system setting); every text and state colour
  /// keeps WCAG AA contrast on the light surfaces (checked by a test).
  static const VehicleTokens light = VehicleTokens(
    background: Color(0xFFF3F2EF),
    surface: Color(0xFFFAF9F7),
    surfaceRaised: Color(0xFFE9E8E4),
    outline: Color(0xFFD3D1CB),
    textPrimary: Color(0xFF16181B),
    textSecondary: Color(0xFF53585E),
    accent: Color(0xFF096A61),
    onAccent: Color(0xFFFFFFFF),
    live: Color(0xFF096A61),
    stale: Color(0xFF8A5700),
    noData: Color(0xFF5B6168),
    notPolled: Color(0xFF50607A),
    error: Color(0xFFB3261E),
    record: Color(0xFFB3261E),
  );

  @override
  VehicleTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
    Color? live,
    Color? stale,
    Color? noData,
    Color? notPolled,
    Color? error,
    Color? record,
  }) {
    return VehicleTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      live: live ?? this.live,
      stale: stale ?? this.stale,
      noData: noData ?? this.noData,
      notPolled: notPolled ?? this.notPolled,
      error: error ?? this.error,
      record: record ?? this.record,
    );
  }

  @override
  VehicleTokens lerp(ThemeExtension<VehicleTokens>? other, double t) {
    if (other is! VehicleTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return VehicleTokens(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      outline: mix(outline, other.outline),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      live: mix(live, other.live),
      stale: mix(stale, other.stale),
      noData: mix(noData, other.noData),
      notPolled: mix(notPolled, other.notPolled),
      error: mix(error, other.error),
      record: mix(record, other.record),
    );
  }
}

/// `context.vehicle` -> the active [VehicleTokens].
extension VehicleThemeContext on BuildContext {
  VehicleTokens get vehicle =>
      Theme.of(this).extension<VehicleTokens>() ?? VehicleTokens.dark;
}
