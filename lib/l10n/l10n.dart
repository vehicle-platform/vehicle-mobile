import 'package:flutter/widgets.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';

export 'package:vehicle_mobile/l10n/app_localizations.dart';

/// `context.l10n` -> the strings of the active locale. Falls back to English
/// when no localisation delegate is mounted (a widget under test, a bare
/// route), so a screen never crashes for want of a delegate.
extension L10nContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

/// Upper-cases [text] for display in the active locale: Turkish maps i to İ
/// and ı to I (Dart's `toUpperCase` is locale-blind).
String upperFor(BuildContext context, String text) {
  final turkish = Localizations.maybeLocaleOf(context)?.languageCode == 'tr';
  return (turkish ? text.replaceAll('i', 'İ').replaceAll('ı', 'I') : text)
      .toUpperCase();
}
