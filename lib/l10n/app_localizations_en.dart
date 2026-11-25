// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vehicle';

  @override
  String get assistantName => 'Ride Assistant';

  @override
  String get navRide => 'Ride';

  @override
  String get navGarage => 'Garage';

  @override
  String get navLogbook => 'Logbook';

  @override
  String get navAssistant => 'Assistant';

  @override
  String get navSettings => 'Settings';

  @override
  String get rideSubLive => 'Live';

  @override
  String get rideSubSignals => 'Signals';

  @override
  String get rideSubRecord => 'Record';

  @override
  String get rideSubDiagnostics => 'Diagnostics';

  @override
  String get garageInbox => 'Inbox';

  @override
  String get garageFaults => 'Faults';

  @override
  String get garageMarkAllRead => 'Mark all as read';

  @override
  String get garageRefresh => 'Refresh';

  @override
  String get garageSelectItem => 'Select an item to see its details';

  @override
  String get logbookSelectRide => 'Select a ride to see its details';

  @override
  String get commandBarTitle => 'Command bar';

  @override
  String get commandBarHint => 'Jump to a screen or ask a question';

  @override
  String get commandBarShortcut => 'Ctrl+K';

  @override
  String get commandBarNoMatch => 'No matching command';

  @override
  String commandGoTo(String destination) {
    return 'Go to $destination';
  }

  @override
  String commandAsk(String assistant, String query) {
    return 'Ask $assistant: $query';
  }

  @override
  String get commandOpenPanel => 'Open the assistant panel';

  @override
  String get commandClosePanel => 'Close the assistant panel';

  @override
  String get panelToggleOpen => 'Show assistant panel';

  @override
  String get panelToggleClose => 'Hide assistant panel';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHint =>
      'Also the language of the assistant\'s answers.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTurkish => 'Türkçe';
}
