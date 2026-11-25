import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';

/// The user's language choice (D-130 item 5, D-125): English by default,
/// Turkish selectable in settings, or follow the system when it is one of the
/// supported languages. Persisted in the preferences; `null` = system.
class LocaleController extends ChangeNotifier {
  LocaleController({Locale? initial}) : _override = initial;

  static const prefsKey = 'ui_locale';

  Locale? _override;

  /// The explicit choice, or null to follow the system.
  Locale? get override => _override;

  /// Loads the saved choice; a missing or unsupported value means "system".
  static Future<LocaleController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(prefsKey);
      return LocaleController(initial: _supported(code));
    } catch (_) {
      return LocaleController();
    }
  }

  static Locale? _supported(String? code) {
    if (code == null) return null;
    for (final l in AppLocalizations.supportedLocales) {
      if (l.languageCode == code) return l;
    }
    return null;
  }

  Future<void> set(Locale? locale) async {
    if (locale?.languageCode == _override?.languageCode) return;
    _override = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(prefsKey);
      } else {
        await prefs.setString(prefsKey, locale.languageCode);
      }
    } catch (_) {
      // The choice still applies for this run.
    }
  }
}

/// Hands the [LocaleController] to the settings screen.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope(
      {super.key, required LocaleController controller, required super.child})
      : super(notifier: controller);

  static LocaleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
}
