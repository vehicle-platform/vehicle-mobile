import 'package:flutter/animation.dart';

/// Spacing scale (logical pixels), an 8-point grid with a 4 px half step.
/// Screens use these instead of literals.
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Minimum interactive size (Material / WCAG touch target, D-130 item 5).
  static const double touchTarget = 48;
}

/// Corner radii (D-130 item 1: at most 8).
abstract final class Radii {
  static const double chip = 4;
  static const double card = 8;
  static const double hero = 8;
}

/// Motion (D-130 item 1): 150-200 ms, ease-out, no bounce.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOut;
}
