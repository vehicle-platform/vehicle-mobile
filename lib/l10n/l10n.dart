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
