import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get appTitle;

  /// No description provided for @assistantName.
  ///
  /// In en, this message translates to:
  /// **'Ride Assistant'**
  String get assistantName;

  /// No description provided for @navRide.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get navRide;

  /// No description provided for @navGarage.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get navGarage;

  /// No description provided for @navLogbook.
  ///
  /// In en, this message translates to:
  /// **'Logbook'**
  String get navLogbook;

  /// No description provided for @navAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get navAssistant;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @rideSubLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get rideSubLive;

  /// No description provided for @rideSubSignals.
  ///
  /// In en, this message translates to:
  /// **'Signals'**
  String get rideSubSignals;

  /// No description provided for @rideSubRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get rideSubRecord;

  /// No description provided for @rideSubDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get rideSubDiagnostics;

  /// No description provided for @garageInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get garageInbox;

  /// No description provided for @garageFaults.
  ///
  /// In en, this message translates to:
  /// **'Faults'**
  String get garageFaults;

  /// No description provided for @garageMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get garageMarkAllRead;

  /// No description provided for @garageRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get garageRefresh;

  /// No description provided for @garageSelectItem.
  ///
  /// In en, this message translates to:
  /// **'Select an item to see its details'**
  String get garageSelectItem;

  /// No description provided for @logbookSelectRide.
  ///
  /// In en, this message translates to:
  /// **'Select a ride to see its details'**
  String get logbookSelectRide;

  /// No description provided for @commandBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Command bar'**
  String get commandBarTitle;

  /// No description provided for @commandBarHint.
  ///
  /// In en, this message translates to:
  /// **'Jump to a screen or ask a question'**
  String get commandBarHint;

  /// No description provided for @commandBarShortcut.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+K'**
  String get commandBarShortcut;

  /// No description provided for @commandBarNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching command'**
  String get commandBarNoMatch;

  /// No description provided for @commandGoTo.
  ///
  /// In en, this message translates to:
  /// **'Go to {destination}'**
  String commandGoTo(String destination);

  /// No description provided for @commandAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask {assistant}: {query}'**
  String commandAsk(String assistant, String query);

  /// No description provided for @commandOpenPanel.
  ///
  /// In en, this message translates to:
  /// **'Open the assistant panel'**
  String get commandOpenPanel;

  /// No description provided for @commandClosePanel.
  ///
  /// In en, this message translates to:
  /// **'Close the assistant panel'**
  String get commandClosePanel;

  /// No description provided for @panelToggleOpen.
  ///
  /// In en, this message translates to:
  /// **'Show assistant panel'**
  String get panelToggleOpen;

  /// No description provided for @panelToggleClose.
  ///
  /// In en, this message translates to:
  /// **'Hide assistant panel'**
  String get panelToggleClose;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Also the language of the assistant\'s answers.'**
  String get settingsLanguageHint;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get languageTurkish;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
