import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// The rider's display choice: follow the system (dark first), always dark,
/// light, or sunlight (the high-contrast light variant for direct daylight).
enum ThemeChoice {
  system('system'),
  dark('dark'),
  light('light'),
  sunlight('sunlight');

  const ThemeChoice(this.storageName);

  final String storageName;

  static ThemeChoice? fromStorage(String? raw) {
    for (final c in values) {
      if (c.storageName == raw) return c;
    }
    return null;
  }
}

/// Holds the [ThemeChoice], persists it in the preferences and maps it to the
/// `MaterialApp` theme fields. A missing or unknown saved value means
/// [ThemeChoice.system].
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeChoice initial = ThemeChoice.system})
      : _choice = initial;

  static const prefsKey = 'ui_theme';

  ThemeChoice _choice;

  /// The choice made before the last switch into sunlight, so the one-tap
  /// toggle on the ride screen returns to it.
  ThemeChoice _beforeSunlight = ThemeChoice.system;

  ThemeChoice get choice => _choice;

  bool get isSunlight => _choice == ThemeChoice.sunlight;

  static Future<ThemeController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ThemeController(
          initial: ThemeChoice.fromStorage(prefs.getString(prefsKey)) ??
              ThemeChoice.system);
    } catch (_) {
      return ThemeController();
    }
  }

  Future<void> set(ThemeChoice choice) async {
    if (choice == _choice) return;
    if (choice == ThemeChoice.sunlight) _beforeSunlight = _choice;
    _choice = choice;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, choice.storageName);
    } catch (_) {
      // The choice still applies for this run.
    }
  }

  /// Sunlight on, or back to the previous choice.
  Future<void> toggleSunlight() =>
      set(isSunlight ? _beforeSunlight : ThemeChoice.sunlight);

  /// The light-brightness theme: the sunlight variant when chosen.
  ThemeData get lightTheme =>
      buildAppTheme(brightness: Brightness.light, sunlight: isSunlight);

  ThemeData get darkTheme => buildAppTheme();

  ThemeMode get themeMode => switch (_choice) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.dark => ThemeMode.dark,
        ThemeChoice.light || ThemeChoice.sunlight => ThemeMode.light,
      };
}

/// Hands the [ThemeController] to the settings and ride screens.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope(
      {super.key, required ThemeController controller, required super.child})
      : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
