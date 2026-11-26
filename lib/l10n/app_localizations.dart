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

  /// No description provided for @alertsAnnounce.
  ///
  /// In en, this message translates to:
  /// **'Warning. {text}'**
  String alertsAnnounce(String text);

  /// No description provided for @alertsSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride alerts'**
  String get alertsSettingsTitle;

  /// No description provided for @alertsSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Types appear here after their first alert. A critical alert always shows its banner; muting it only silences the voice. A warning can be muted completely (it stays in the inbox).'**
  String get alertsSettingsHint;

  /// No description provided for @alertsSettingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No alert types yet.'**
  String get alertsSettingsEmpty;

  /// No description provided for @alertsMuteVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get alertsMuteVoice;

  /// No description provided for @alertsMuteShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get alertsMuteShow;

  /// No description provided for @alertsClassCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get alertsClassCritical;

  /// No description provided for @alertsClassWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get alertsClassWarning;

  /// No description provided for @assistantGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, I am the Ride Assistant. What would you like to know?'**
  String get assistantGreeting;

  /// No description provided for @assistantExample1.
  ///
  /// In en, this message translates to:
  /// **'How was my last ride?'**
  String get assistantExample1;

  /// No description provided for @assistantExample2.
  ///
  /// In en, this message translates to:
  /// **'Summary of the last ride'**
  String get assistantExample2;

  /// No description provided for @assistantExample3.
  ///
  /// In en, this message translates to:
  /// **'Any recorded faults?'**
  String get assistantExample3;

  /// No description provided for @assistantHint.
  ///
  /// In en, this message translates to:
  /// **'Type a question'**
  String get assistantHint;

  /// No description provided for @assistantHintListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get assistantHintListening;

  /// No description provided for @assistantSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get assistantSend;

  /// No description provided for @assistantClear.
  ///
  /// In en, this message translates to:
  /// **'Clear conversation'**
  String get assistantClear;

  /// No description provided for @assistantRideChip.
  ///
  /// In en, this message translates to:
  /// **'Ride {id}'**
  String assistantRideChip(String id);

  /// No description provided for @assistantStepReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the data ...'**
  String get assistantStepReading;

  /// No description provided for @assistantStepReadingRide.
  ///
  /// In en, this message translates to:
  /// **'Reading ride {id} ...'**
  String assistantStepReadingRide(String id);

  /// No description provided for @assistantSourceLlm.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistantSourceLlm;

  /// No description provided for @assistantSourceTemplate.
  ///
  /// In en, this message translates to:
  /// **'Verified from data'**
  String get assistantSourceTemplate;

  /// No description provided for @assistantSourceUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Could not answer'**
  String get assistantSourceUnsupported;

  /// No description provided for @assistantSourceError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get assistantSourceError;

  /// No description provided for @assistantModelTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template answer (no model)'**
  String get assistantModelTemplate;

  /// No description provided for @assistantModelNone.
  ///
  /// In en, this message translates to:
  /// **'Not answered (no model)'**
  String get assistantModelNone;

  /// No description provided for @assistantModelChipLabel.
  ///
  /// In en, this message translates to:
  /// **'Assistant model: {text}'**
  String assistantModelChipLabel(String text);

  /// No description provided for @assistantComputedBy.
  ///
  /// In en, this message translates to:
  /// **'computed by '**
  String get assistantComputedBy;

  /// No description provided for @assistantArguments.
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get assistantArguments;

  /// No description provided for @assistantResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get assistantResult;

  /// No description provided for @assistantResultEmpty.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get assistantResultEmpty;

  /// No description provided for @assistantItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String assistantItemCount(int count);

  /// No description provided for @assistantMoreItems.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String assistantMoreItems(int count);

  /// No description provided for @assistantTruncated.
  ///
  /// In en, this message translates to:
  /// **'truncated'**
  String get assistantTruncated;

  /// No description provided for @assistantFailSettings.
  ///
  /// In en, this message translates to:
  /// **'Could not read the host settings.'**
  String get assistantFailSettings;

  /// No description provided for @assistantFailNoHost.
  ///
  /// In en, this message translates to:
  /// **'No host with a device token is configured. Add one in Settings > Hosts.'**
  String get assistantFailNoHost;

  /// No description provided for @assistantFailUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'The device token was rejected by \"{host}\". Check the token in Settings > Hosts.'**
  String assistantFailUnauthorized(String host);

  /// No description provided for @assistantFailInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the message: {message}'**
  String assistantFailInvalid(String message);

  /// No description provided for @assistantFailRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Rate limited. Try again shortly.'**
  String get assistantFailRateLimited;

  /// No description provided for @assistantFailRateLimitedIn.
  ///
  /// In en, this message translates to:
  /// **'Rate limited. Try again in {seconds} s.'**
  String assistantFailRateLimitedIn(int seconds);

  /// No description provided for @assistantFailDisabled.
  ///
  /// In en, this message translates to:
  /// **'The assistant is disabled on \"{host}\".'**
  String assistantFailDisabled(String host);

  /// No description provided for @assistantFailUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Host unreachable: \"{host}\".'**
  String assistantFailUnreachable(String host);

  /// No description provided for @assistantFailFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed: {message}'**
  String assistantFailFailed(String message);

  /// No description provided for @assistantFailUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown error'**
  String get assistantFailUnknown;

  /// No description provided for @assistantTheHost.
  ///
  /// In en, this message translates to:
  /// **'the host'**
  String get assistantTheHost;

  /// No description provided for @assistantVoiceInitTimeout.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is not available. You can type the question.'**
  String get assistantVoiceInitTimeout;

  /// No description provided for @assistantVoiceNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'I did not hear you. Try again?'**
  String get assistantVoiceNoSpeech;

  /// No description provided for @assistantVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is not available right now. You can type the question.'**
  String get assistantVoiceUnavailable;

  /// No description provided for @assistantVoicePermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission was not granted or this device has no speech recognition. You can allow it in the settings or type the question.'**
  String get assistantVoicePermission;

  /// No description provided for @assistantVoiceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition for this language is not installed on this device. You can type the question.'**
  String get assistantVoiceLanguage;

  /// No description provided for @assistantVoiceNetwork.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition needs an internet connection.'**
  String get assistantVoiceNetwork;

  /// No description provided for @assistantRouteIntercom.
  ///
  /// In en, this message translates to:
  /// **'Intercom connected'**
  String get assistantRouteIntercom;

  /// No description provided for @assistantRoutePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone microphone'**
  String get assistantRoutePhone;

  /// No description provided for @assistantMicStop.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get assistantMicStop;

  /// No description provided for @assistantMicSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Stop reading and speak'**
  String get assistantMicSpeaking;

  /// No description provided for @assistantMicStart.
  ///
  /// In en, this message translates to:
  /// **'Ask by voice'**
  String get assistantMicStart;

  /// No description provided for @assistantClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get assistantClose;

  /// No description provided for @assistantHoldToTalk.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk'**
  String get assistantHoldToTalk;

  /// No description provided for @assistantReleaseToSend.
  ///
  /// In en, this message translates to:
  /// **'Release to send'**
  String get assistantReleaseToSend;

  /// No description provided for @assistantPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the microphone ...'**
  String get assistantPreparing;

  /// No description provided for @formatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get formatToday;

  /// No description provided for @formatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get formatYesterday;

  /// No description provided for @garageNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get garageNotificationsTitle;

  /// No description provided for @garageNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get garageNotificationTitle;

  /// No description provided for @garageBellTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get garageBellTooltip;

  /// No description provided for @garageBellTooltipUnread.
  ///
  /// In en, this message translates to:
  /// **'Notifications ({count} unread)'**
  String garageBellTooltipUnread(int count);

  /// No description provided for @garageSeverityCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get garageSeverityCritical;

  /// No description provided for @garageSeverityWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get garageSeverityWarning;

  /// No description provided for @garageSeverityInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get garageSeverityInfo;

  /// No description provided for @garageDayNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get garageDayNoDate;

  /// No description provided for @garageEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get garageEmptyTitle;

  /// No description provided for @garageEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Ride summaries and alerts appear here.'**
  String get garageEmptyHint;

  /// No description provided for @garageUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get garageUnread;

  /// No description provided for @garageOpenRide.
  ///
  /// In en, this message translates to:
  /// **'Open ride'**
  String get garageOpenRide;

  /// No description provided for @garageAskAssistant.
  ///
  /// In en, this message translates to:
  /// **'Ask {assistant}'**
  String garageAskAssistant(String assistant);

  /// No description provided for @garageAskQuestion.
  ///
  /// In en, this message translates to:
  /// **'What can you tell me about the notification \"{title}\"?'**
  String garageAskQuestion(String title);

  /// No description provided for @garageFaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Faults'**
  String get garageFaultsTitle;

  /// No description provided for @garageFaultsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading faults...'**
  String get garageFaultsLoading;

  /// No description provided for @garageFaultsNoServer.
  ///
  /// In en, this message translates to:
  /// **'No vehicle-server configured. Add a host with its device token in Settings.'**
  String get garageFaultsNoServer;

  /// No description provided for @garageFaultsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get garageFaultsRetry;

  /// No description provided for @garageFaultsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The host lists no faults.'**
  String get garageFaultsEmpty;

  /// No description provided for @garageAnnounceAdviseStop.
  ///
  /// In en, this message translates to:
  /// **'Stop in a safe place and have the engine checked.'**
  String get garageAnnounceAdviseStop;

  /// No description provided for @garageAnnounceFault.
  ///
  /// In en, this message translates to:
  /// **'High-priority warning: {title}. Stop in a safe place and have the engine checked.'**
  String garageAnnounceFault(String title);

  /// No description provided for @logbookRideHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride history'**
  String get logbookRideHistoryTitle;

  /// No description provided for @logbookRideSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride summary'**
  String get logbookRideSummaryTitle;

  /// No description provided for @logbookBringupTitle.
  ///
  /// In en, this message translates to:
  /// **'Bring-up check'**
  String get logbookBringupTitle;

  /// No description provided for @logbookRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get logbookRefresh;

  /// No description provided for @logbookRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get logbookRetry;

  /// No description provided for @logbookOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get logbookOpenSettings;

  /// No description provided for @logbookAskAssistant.
  ///
  /// In en, this message translates to:
  /// **'Ask the assistant'**
  String get logbookAskAssistant;

  /// No description provided for @logbookLoadingRides.
  ///
  /// In en, this message translates to:
  /// **'Loading rides...'**
  String get logbookLoadingRides;

  /// No description provided for @logbookLoadingSummary.
  ///
  /// In en, this message translates to:
  /// **'Loading ride summary...'**
  String get logbookLoadingSummary;

  /// No description provided for @logbookLoadingBringup.
  ///
  /// In en, this message translates to:
  /// **'Loading bring-up check...'**
  String get logbookLoadingBringup;

  /// No description provided for @logbookNoServer.
  ///
  /// In en, this message translates to:
  /// **'No vehicle-server configured. Set the server URL and API token in Settings.'**
  String get logbookNoServer;

  /// No description provided for @logbookCleartextWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: http:// sends the API token and ride data unencrypted. Use it only on a trusted local network; use https:// for any server reachable from outside.'**
  String get logbookCleartextWarning;

  /// No description provided for @logbookAllRides.
  ///
  /// In en, this message translates to:
  /// **'All rides'**
  String get logbookAllRides;

  /// No description provided for @logbookRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String logbookRange(String from, String to);

  /// No description provided for @logbookNoRidesInRange.
  ///
  /// In en, this message translates to:
  /// **'No rides in this range.'**
  String get logbookNoRidesInRange;

  /// No description provided for @logbookSkippedHint.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session without a stored summary skipped.} other{{count} sessions without a stored summary skipped.}}'**
  String logbookSkippedHint(int count);

  /// No description provided for @logbookDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get logbookDateRange;

  /// No description provided for @logbookChangeRange.
  ///
  /// In en, this message translates to:
  /// **'Change range'**
  String get logbookChangeRange;

  /// No description provided for @logbookClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get logbookClear;

  /// No description provided for @logbookColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get logbookColumns;

  /// No description provided for @logbookUpToTwo.
  ///
  /// In en, this message translates to:
  /// **'up to two'**
  String get logbookUpToTwo;

  /// No description provided for @logbookRideCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ride} other{{count} rides}}'**
  String logbookRideCount(int count);

  /// No description provided for @logbookSkippedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String logbookSkippedCount(int count);

  /// No description provided for @logbookUnknownTime.
  ///
  /// In en, this message translates to:
  /// **'unknown time'**
  String get logbookUnknownTime;

  /// No description provided for @logbookSignals.
  ///
  /// In en, this message translates to:
  /// **'Signals'**
  String get logbookSignals;

  /// No description provided for @logbookPerGear.
  ///
  /// In en, this message translates to:
  /// **'Per-gear signals'**
  String get logbookPerGear;

  /// No description provided for @logbookBinned.
  ///
  /// In en, this message translates to:
  /// **'Binned signals'**
  String get logbookBinned;

  /// No description provided for @logbookCoverage.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get logbookCoverage;

  /// No description provided for @logbookHealthWindows.
  ///
  /// In en, this message translates to:
  /// **'Health windows'**
  String get logbookHealthWindows;

  /// No description provided for @logbookNoSummary.
  ///
  /// In en, this message translates to:
  /// **'No stored ride summary for this session.'**
  String get logbookNoSummary;

  /// No description provided for @logbookDefsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Decoded with other defs bin edges: {names}.'**
  String logbookDefsMismatch(String names);

  /// No description provided for @logbookRideDefinition.
  ///
  /// In en, this message translates to:
  /// **'ride {value}'**
  String logbookRideDefinition(String value);

  /// No description provided for @logbookDefsVersion.
  ///
  /// In en, this message translates to:
  /// **'defs {value}'**
  String logbookDefsVersion(String value);

  /// No description provided for @logbookNoSignals.
  ///
  /// In en, this message translates to:
  /// **'No stored signals in this ride summary.'**
  String get logbookNoSignals;

  /// No description provided for @logbookGear.
  ///
  /// In en, this message translates to:
  /// **'Gear {n}'**
  String logbookGear(int n);

  /// No description provided for @logbookNoGears.
  ///
  /// In en, this message translates to:
  /// **'No stored gears.'**
  String get logbookNoGears;

  /// No description provided for @logbookAxisUnsupported.
  ///
  /// In en, this message translates to:
  /// **'{n}-axis summaries are not shown on the phone yet.'**
  String logbookAxisUnsupported(int n);

  /// No description provided for @logbookTotalOutside.
  ///
  /// In en, this message translates to:
  /// **'total {total} · outside {outside}'**
  String logbookTotalOutside(String total, String outside);

  /// No description provided for @logbookNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available ({n})'**
  String logbookNotAvailable(int n);

  /// No description provided for @logbookPendingInputs.
  ///
  /// In en, this message translates to:
  /// **'pending: {list}'**
  String logbookPendingInputs(String list);

  /// No description provided for @logbookMissingInputs.
  ///
  /// In en, this message translates to:
  /// **'missing: {list}'**
  String logbookMissingInputs(String list);

  /// No description provided for @logbookColumnsAxis.
  ///
  /// In en, this message translates to:
  /// **'columns: {input} [{unit}]'**
  String logbookColumnsAxis(String input, String unit);

  /// No description provided for @logbookRowsAxis.
  ///
  /// In en, this message translates to:
  /// **'rows: {input} [{unit}]'**
  String logbookRowsAxis(String input, String unit);

  /// No description provided for @logbookSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get logbookSession;

  /// No description provided for @logbookBringupUnsupported.
  ///
  /// In en, this message translates to:
  /// **'this server has no bring-up check (needs vehicle-server with the bring-up route, server#50)'**
  String get logbookBringupUnsupported;

  /// No description provided for @logbookBringupUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized: check the API token in Settings.'**
  String get logbookBringupUnauthorized;

  /// No description provided for @logbookBringupNotFound.
  ///
  /// In en, this message translates to:
  /// **'the server does not have this session (upload it first)'**
  String get logbookBringupNotFound;

  /// No description provided for @logbookBringupInvalid.
  ///
  /// In en, this message translates to:
  /// **'invalid request'**
  String get logbookBringupInvalid;

  /// No description provided for @logbookBringupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'server unavailable'**
  String get logbookBringupUnavailable;

  /// No description provided for @logbookBringupFailed.
  ///
  /// In en, this message translates to:
  /// **'request failed'**
  String get logbookBringupFailed;

  /// No description provided for @logbookSettingsReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the server settings.'**
  String get logbookSettingsReadFailed;

  /// No description provided for @logbookNoBringupAnswer.
  ///
  /// In en, this message translates to:
  /// **'The server returned no bring-up answer.'**
  String get logbookNoBringupAnswer;

  /// No description provided for @logbookNoChecks.
  ///
  /// In en, this message translates to:
  /// **'The server returned no checks for this gate.'**
  String get logbookNoChecks;

  /// No description provided for @logbookChecks.
  ///
  /// In en, this message translates to:
  /// **'Checks'**
  String get logbookChecks;

  /// No description provided for @logbookManualPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 manual check pending: {list}} other{{count} manual checks pending: {list}}}'**
  String logbookManualPending(int count, String list);

  /// No description provided for @logbookWarningsList.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 warning: {list}} other{{count} warnings: {list}}}'**
  String logbookWarningsList(int count, String list);

  /// No description provided for @logbookBringupLegend.
  ///
  /// In en, this message translates to:
  /// **'manual = you judge it at the bike; unknown = the session has no data for it.'**
  String get logbookBringupLegend;

  /// No description provided for @logbookMeasured.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get logbookMeasured;

  /// No description provided for @logbookExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get logbookExpected;

  /// No description provided for @logbookSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get logbookSource;

  /// No description provided for @logbookNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get logbookNote;

  /// No description provided for @logbookWindowsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading window instances...'**
  String get logbookWindowsLoading;

  /// No description provided for @logbookWindowsMissingReport.
  ///
  /// In en, this message translates to:
  /// **'No window instances in this report (older server, or run `vehicle-server derive <id>` on the server).'**
  String get logbookWindowsMissingReport;

  /// No description provided for @logbookWindowsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable.'**
  String get logbookWindowsUnavailable;

  /// No description provided for @logbookWindowsNone.
  ///
  /// In en, this message translates to:
  /// **'No window instances stored.'**
  String get logbookWindowsNone;

  /// No description provided for @logbookWindowsCounts.
  ///
  /// In en, this message translates to:
  /// **'{instances} instances, {qualifying} qualifying'**
  String logbookWindowsCounts(int instances, int qualifying);

  /// No description provided for @logbookColStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get logbookColStart;

  /// No description provided for @logbookColEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get logbookColEnd;

  /// No description provided for @logbookColDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get logbookColDuration;

  /// No description provided for @logbookColCloseReason.
  ///
  /// In en, this message translates to:
  /// **'Close reason'**
  String get logbookColCloseReason;

  /// No description provided for @logbookColQualifies.
  ///
  /// In en, this message translates to:
  /// **'Qualifies'**
  String get logbookColQualifies;

  /// No description provided for @logbookColFirst.
  ///
  /// In en, this message translates to:
  /// **'First'**
  String get logbookColFirst;

  /// No description provided for @logbookYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get logbookYes;

  /// No description provided for @logbookNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get logbookNo;

  /// No description provided for @logbookFirstMark.
  ///
  /// In en, this message translates to:
  /// **'first'**
  String get logbookFirstMark;

  /// No description provided for @quantityRideDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get quantityRideDistance;

  /// No description provided for @quantityRideTime.
  ///
  /// In en, this message translates to:
  /// **'Ride time'**
  String get quantityRideTime;

  /// No description provided for @quantityRideStopCount.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get quantityRideStopCount;

  /// No description provided for @quantityRideIdleTime.
  ///
  /// In en, this message translates to:
  /// **'Idle time'**
  String get quantityRideIdleTime;

  /// No description provided for @quantityRideWarmupTime.
  ///
  /// In en, this message translates to:
  /// **'Warm-up time'**
  String get quantityRideWarmupTime;

  /// No description provided for @quantityRideEndCoolantTemp.
  ///
  /// In en, this message translates to:
  /// **'Coolant at end'**
  String get quantityRideEndCoolantTemp;

  /// No description provided for @quantityRideStartCoolantTemp.
  ///
  /// In en, this message translates to:
  /// **'Coolant at start'**
  String get quantityRideStartCoolantTemp;

  /// No description provided for @quantityRideFuelConsumption.
  ///
  /// In en, this message translates to:
  /// **'Fuel consumption'**
  String get quantityRideFuelConsumption;

  /// No description provided for @quantityRideFuelUsed.
  ///
  /// In en, this message translates to:
  /// **'Fuel used'**
  String get quantityRideFuelUsed;

  /// No description provided for @quantityRideRestVoltage.
  ///
  /// In en, this message translates to:
  /// **'Battery at rest'**
  String get quantityRideRestVoltage;

  /// No description provided for @quantityRideShiftCount.
  ///
  /// In en, this message translates to:
  /// **'Gear shifts'**
  String get quantityRideShiftCount;

  /// No description provided for @quantityRideAggressiveness.
  ///
  /// In en, this message translates to:
  /// **'Riding intensity'**
  String get quantityRideAggressiveness;

  /// No description provided for @logbookCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get logbookCompare;

  /// No description provided for @logbookCompareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare rides'**
  String get logbookCompareTitle;

  /// No description provided for @logbookCompareHint.
  ///
  /// In en, this message translates to:
  /// **'Pick up to two more quantities to show on every ride.'**
  String get logbookCompareHint;

  /// No description provided for @logbookRiderQuantities.
  ///
  /// In en, this message translates to:
  /// **'Ride quantities'**
  String get logbookRiderQuantities;

  /// No description provided for @logbookAllSignals.
  ///
  /// In en, this message translates to:
  /// **'All signals'**
  String get logbookAllSignals;

  /// No description provided for @logbookCompareDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get logbookCompareDone;

  /// No description provided for @rideLiveOpenRecord.
  ///
  /// In en, this message translates to:
  /// **'Open the Record screen'**
  String get rideLiveOpenRecord;

  /// No description provided for @rideSynthTitle.
  ///
  /// In en, this message translates to:
  /// **'SYNTHETIC DATA'**
  String get rideSynthTitle;

  /// No description provided for @rideSynthText.
  ///
  /// In en, this message translates to:
  /// **'The node is generating mock values. Nothing shown here comes from the bike.'**
  String get rideSynthText;

  /// No description provided for @rideRecordCta.
  ///
  /// In en, this message translates to:
  /// **'RECORD A SESSION'**
  String get rideRecordCta;

  /// No description provided for @rideStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get rideStatusLabel;

  /// No description provided for @rideConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get rideConnected;

  /// No description provided for @rideDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get rideDisconnected;

  /// No description provided for @rideNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get rideNotConnected;

  /// No description provided for @rideWaitingFirstPacket.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first packet'**
  String get rideWaitingFirstPacket;

  /// No description provided for @rideLastPacketAgoSub.
  ///
  /// In en, this message translates to:
  /// **'Last packet {age} ago'**
  String rideLastPacketAgoSub(String age);

  /// No description provided for @rideScanningTitle.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get rideScanningTitle;

  /// No description provided for @rideLookingForBike.
  ///
  /// In en, this message translates to:
  /// **'Looking for the bike'**
  String get rideLookingForBike;

  /// No description provided for @rideTapConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap Connect to scan for the bike'**
  String get rideTapConnect;

  /// No description provided for @rideDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get rideDisconnect;

  /// No description provided for @rideConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get rideConnect;

  /// No description provided for @rideScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get rideScanning;

  /// No description provided for @rideBleDevice.
  ///
  /// In en, this message translates to:
  /// **'BLE {device}'**
  String rideBleDevice(String device);

  /// No description provided for @rideBleConnected.
  ///
  /// In en, this message translates to:
  /// **'BLE connected'**
  String get rideBleConnected;

  /// No description provided for @rideBleDisconnected.
  ///
  /// In en, this message translates to:
  /// **'BLE disconnected'**
  String get rideBleDisconnected;

  /// No description provided for @rideEcuPresent.
  ///
  /// In en, this message translates to:
  /// **'ECU present'**
  String get rideEcuPresent;

  /// No description provided for @rideEcuNotFound.
  ///
  /// In en, this message translates to:
  /// **'ECU not found'**
  String get rideEcuNotFound;

  /// No description provided for @rideEcuUnknown.
  ///
  /// In en, this message translates to:
  /// **'ECU --'**
  String get rideEcuUnknown;

  /// No description provided for @rideCanUnknown.
  ///
  /// In en, this message translates to:
  /// **'CAN --'**
  String get rideCanUnknown;

  /// No description provided for @ridePollerOff.
  ///
  /// In en, this message translates to:
  /// **'Poller off'**
  String get ridePollerOff;

  /// No description provided for @rideForeignLatched.
  ///
  /// In en, this message translates to:
  /// **'Foreign tester latched'**
  String get rideForeignLatched;

  /// No description provided for @rideBusOffLatched.
  ///
  /// In en, this message translates to:
  /// **'Bus-off latched'**
  String get rideBusOffLatched;

  /// No description provided for @rideLatchesClear.
  ///
  /// In en, this message translates to:
  /// **'Latches clear'**
  String get rideLatchesClear;

  /// No description provided for @rideSyntheticData.
  ///
  /// In en, this message translates to:
  /// **'Synthetic data'**
  String get rideSyntheticData;

  /// No description provided for @rideImuActive.
  ///
  /// In en, this message translates to:
  /// **'IMU active'**
  String get rideImuActive;

  /// No description provided for @rideImuInactive.
  ///
  /// In en, this message translates to:
  /// **'IMU inactive'**
  String get rideImuInactive;

  /// No description provided for @rideImuUnknown.
  ///
  /// In en, this message translates to:
  /// **'IMU --'**
  String get rideImuUnknown;

  /// No description provided for @rideCanNa.
  ///
  /// In en, this message translates to:
  /// **'CAN n/a'**
  String get rideCanNa;

  /// No description provided for @rideCanRunning.
  ///
  /// In en, this message translates to:
  /// **'CAN running'**
  String get rideCanRunning;

  /// No description provided for @rideCanErrorWarning.
  ///
  /// In en, this message translates to:
  /// **'CAN error warning'**
  String get rideCanErrorWarning;

  /// No description provided for @rideCanBusOff.
  ///
  /// In en, this message translates to:
  /// **'CAN bus-off'**
  String get rideCanBusOff;

  /// No description provided for @rideCanStopped.
  ///
  /// In en, this message translates to:
  /// **'CAN stopped'**
  String get rideCanStopped;

  /// No description provided for @rideCanNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'CAN not installed'**
  String get rideCanNotInstalled;

  /// No description provided for @rideGpsNone.
  ///
  /// In en, this message translates to:
  /// **'GPS --'**
  String get rideGpsNone;

  /// No description provided for @rideGpsNotOffered.
  ///
  /// In en, this message translates to:
  /// **'GPS not offered'**
  String get rideGpsNotOffered;

  /// No description provided for @rideGpsPairing.
  ///
  /// In en, this message translates to:
  /// **'GPS pairing...'**
  String get rideGpsPairing;

  /// No description provided for @rideGpsPairPhone.
  ///
  /// In en, this message translates to:
  /// **'GPS: pair phone with bike'**
  String get rideGpsPairPhone;

  /// No description provided for @rideGpsWaiting.
  ///
  /// In en, this message translates to:
  /// **'GPS waiting for data'**
  String get rideGpsWaiting;

  /// No description provided for @rideGpsFix.
  ///
  /// In en, this message translates to:
  /// **'GPS {fix} · {sats} sats'**
  String rideGpsFix(String fix, int sats);

  /// No description provided for @rideSigLive.
  ///
  /// In en, this message translates to:
  /// **'live'**
  String get rideSigLive;

  /// No description provided for @rideSigPolled.
  ///
  /// In en, this message translates to:
  /// **'polled'**
  String get rideSigPolled;

  /// No description provided for @rideSigCandidates.
  ///
  /// In en, this message translates to:
  /// **'candidates'**
  String get rideSigCandidates;

  /// No description provided for @rideFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get rideFilterAll;

  /// No description provided for @rideFilterPolled.
  ///
  /// In en, this message translates to:
  /// **'Polled'**
  String get rideFilterPolled;

  /// No description provided for @rideFilterCandidates.
  ///
  /// In en, this message translates to:
  /// **'Candidates'**
  String get rideFilterCandidates;

  /// No description provided for @rideGroupLive.
  ///
  /// In en, this message translates to:
  /// **'{live} / {total} live'**
  String rideGroupLive(int live, int total);

  /// No description provided for @ridePollEvery.
  ///
  /// In en, this message translates to:
  /// **'Poll every {ms} ms'**
  String ridePollEvery(int ms);

  /// No description provided for @rideAgeDetail.
  ///
  /// In en, this message translates to:
  /// **'Age {age} · {detail}'**
  String rideAgeDetail(String age, String detail);

  /// No description provided for @rideNotPolled.
  ///
  /// In en, this message translates to:
  /// **'Not polled'**
  String get rideNotPolled;

  /// No description provided for @rideReportedByNode.
  ///
  /// In en, this message translates to:
  /// **'Reported by the node'**
  String get rideReportedByNode;

  /// No description provided for @rideDiagLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get rideDiagLink;

  /// No description provided for @rideDiagBle.
  ///
  /// In en, this message translates to:
  /// **'BLE'**
  String get rideDiagBle;

  /// No description provided for @rideDiagDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get rideDiagDevice;

  /// No description provided for @rideDiagAttMtu.
  ///
  /// In en, this message translates to:
  /// **'ATT MTU'**
  String get rideDiagAttMtu;

  /// No description provided for @rideDiagRequestedMtu.
  ///
  /// In en, this message translates to:
  /// **'Requested MTU'**
  String get rideDiagRequestedMtu;

  /// No description provided for @rideDiagPacketVersion.
  ///
  /// In en, this message translates to:
  /// **'Packet version'**
  String get rideDiagPacketVersion;

  /// No description provided for @rideDiagLastPacket.
  ///
  /// In en, this message translates to:
  /// **'Last packet'**
  String get rideDiagLastPacket;

  /// No description provided for @rideDiagAgoSuffix.
  ///
  /// In en, this message translates to:
  /// **'{age} ago'**
  String rideDiagAgoSuffix(String age);

  /// No description provided for @rideDiagDeviceTime.
  ///
  /// In en, this message translates to:
  /// **'Device time'**
  String get rideDiagDeviceTime;

  /// No description provided for @rideDiagPackets.
  ///
  /// In en, this message translates to:
  /// **'Packets'**
  String get rideDiagPackets;

  /// No description provided for @rideDiagReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get rideDiagReceived;

  /// No description provided for @rideDiagLostGaps.
  ///
  /// In en, this message translates to:
  /// **'Lost (sequence gaps)'**
  String get rideDiagLostGaps;

  /// No description provided for @rideDiagLoss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get rideDiagLoss;

  /// No description provided for @rideDiagRejectedVersion.
  ///
  /// In en, this message translates to:
  /// **'Rejected (version)'**
  String get rideDiagRejectedVersion;

  /// No description provided for @rideDiagRejectedSize.
  ///
  /// In en, this message translates to:
  /// **'Rejected (size)'**
  String get rideDiagRejectedSize;

  /// No description provided for @rideDiagCanBus.
  ///
  /// In en, this message translates to:
  /// **'Vehicle CAN bus'**
  String get rideDiagCanBus;

  /// No description provided for @rideDiagBusState.
  ///
  /// In en, this message translates to:
  /// **'Bus state'**
  String get rideDiagBusState;

  /// No description provided for @rideDiagTxErrors.
  ///
  /// In en, this message translates to:
  /// **'TX errors'**
  String get rideDiagTxErrors;

  /// No description provided for @rideDiagRxErrors.
  ///
  /// In en, this message translates to:
  /// **'RX errors'**
  String get rideDiagRxErrors;

  /// No description provided for @rideDiagBusOffEvents.
  ///
  /// In en, this message translates to:
  /// **'Bus-off events'**
  String get rideDiagBusOffEvents;

  /// No description provided for @rideDiagUnansweredDids.
  ///
  /// In en, this message translates to:
  /// **'Unanswered DIDs'**
  String get rideDiagUnansweredDids;

  /// No description provided for @rideDiagPollerEnabled.
  ///
  /// In en, this message translates to:
  /// **'Poller enabled'**
  String get rideDiagPollerEnabled;

  /// No description provided for @rideDiagForeignLatched.
  ///
  /// In en, this message translates to:
  /// **'Foreign tester latched'**
  String get rideDiagForeignLatched;

  /// No description provided for @rideDiagBusOffLatched.
  ///
  /// In en, this message translates to:
  /// **'Bus-off latched'**
  String get rideDiagBusOffLatched;

  /// No description provided for @rideDiagSynthetic.
  ///
  /// In en, this message translates to:
  /// **'Synthetic data'**
  String get rideDiagSynthetic;

  /// No description provided for @rideYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get rideYes;

  /// No description provided for @rideNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get rideNo;

  /// No description provided for @rideDiagCanNeeds.
  ///
  /// In en, this message translates to:
  /// **'CAN health needs a version {version} or newer packet.'**
  String rideDiagCanNeeds(String version);

  /// No description provided for @rideDiagTester.
  ///
  /// In en, this message translates to:
  /// **'Tester (diagnostic poller)'**
  String get rideDiagTester;

  /// No description provided for @rideDiagStepGapMax.
  ///
  /// In en, this message translates to:
  /// **'Step gap, max'**
  String get rideDiagStepGapMax;

  /// No description provided for @rideDiagStepGapOver.
  ///
  /// In en, this message translates to:
  /// **'Step gap, over limit'**
  String get rideDiagStepGapOver;

  /// No description provided for @rideDiagRoundTrip.
  ///
  /// In en, this message translates to:
  /// **'Round trip, rotating DID'**
  String get rideDiagRoundTrip;

  /// No description provided for @rideDiagDid.
  ///
  /// In en, this message translates to:
  /// **'DID'**
  String get rideDiagDid;

  /// No description provided for @rideDiagMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get rideDiagMin;

  /// No description provided for @rideDiagMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get rideDiagMax;

  /// No description provided for @rideDiagMean.
  ///
  /// In en, this message translates to:
  /// **'Mean'**
  String get rideDiagMean;

  /// No description provided for @rideDiagSamples.
  ///
  /// In en, this message translates to:
  /// **'Samples'**
  String get rideDiagSamples;

  /// No description provided for @rideDiagNrc78.
  ///
  /// In en, this message translates to:
  /// **'NRC 0x78 (pending)'**
  String get rideDiagNrc78;

  /// No description provided for @rideDiagTesterNeeds.
  ///
  /// In en, this message translates to:
  /// **'Tester stats need a version {version} packet.'**
  String rideDiagTesterNeeds(String version);

  /// No description provided for @rideRecTabRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get rideRecTabRecord;

  /// No description provided for @rideRecTabSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get rideRecTabSessions;

  /// No description provided for @rideRecServerRides.
  ///
  /// In en, this message translates to:
  /// **'Server rides'**
  String get rideRecServerRides;

  /// No description provided for @rideRecRunning.
  ///
  /// In en, this message translates to:
  /// **'REC {duration}'**
  String rideRecRunning(String duration);

  /// No description provided for @rideRecKeepOn.
  ///
  /// In en, this message translates to:
  /// **'Keep this screen on and the app in the foreground while recording. Android may kill the BLE connection if the app is backgrounded or killed -- there is no foreground service yet.'**
  String get rideRecKeepOn;

  /// No description provided for @rideRecStop.
  ///
  /// In en, this message translates to:
  /// **'STOP RECORDING'**
  String get rideRecStop;

  /// No description provided for @rideRecStart.
  ///
  /// In en, this message translates to:
  /// **'START RECORDING'**
  String get rideRecStart;

  /// No description provided for @rideRecMetadata.
  ///
  /// In en, this message translates to:
  /// **'Session metadata'**
  String get rideRecMetadata;

  /// No description provided for @rideRecRiderName.
  ///
  /// In en, this message translates to:
  /// **'Rider name'**
  String get rideRecRiderName;

  /// No description provided for @rideRecRiderWeight.
  ///
  /// In en, this message translates to:
  /// **'Rider weight (kg)'**
  String get rideRecRiderWeight;

  /// No description provided for @rideRecExtraLoad.
  ///
  /// In en, this message translates to:
  /// **'Extra load (kg)'**
  String get rideRecExtraLoad;

  /// No description provided for @rideRecAmbientTemp.
  ///
  /// In en, this message translates to:
  /// **'Ambient temp (°C)'**
  String get rideRecAmbientTemp;

  /// No description provided for @rideRecWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get rideRecWeather;

  /// No description provided for @rideRecTireFront.
  ///
  /// In en, this message translates to:
  /// **'Tire pressure front (bar)'**
  String get rideRecTireFront;

  /// No description provided for @rideRecTireRear.
  ///
  /// In en, this message translates to:
  /// **'Tire pressure rear (bar)'**
  String get rideRecTireRear;

  /// No description provided for @rideRecFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel level (e.g. full, 1/2, reserve)'**
  String get rideRecFuel;

  /// No description provided for @rideRecVehicleConfig.
  ///
  /// In en, this message translates to:
  /// **'Vehicle config (gearing/exhaust/filter)'**
  String get rideRecVehicleConfig;

  /// No description provided for @rideRecCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition label (healthy or fault type)'**
  String get rideRecCondition;

  /// No description provided for @rideRecRouteType.
  ///
  /// In en, this message translates to:
  /// **'Route type'**
  String get rideRecRouteType;

  /// No description provided for @rideRecNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get rideRecNote;

  /// No description provided for @rideWeatherDry.
  ///
  /// In en, this message translates to:
  /// **'dry'**
  String get rideWeatherDry;

  /// No description provided for @rideWeatherWet.
  ///
  /// In en, this message translates to:
  /// **'wet'**
  String get rideWeatherWet;

  /// No description provided for @rideWeatherUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get rideWeatherUnknown;

  /// No description provided for @rideRouteUrban.
  ///
  /// In en, this message translates to:
  /// **'urban'**
  String get rideRouteUrban;

  /// No description provided for @rideRouteRural.
  ///
  /// In en, this message translates to:
  /// **'rural'**
  String get rideRouteRural;

  /// No description provided for @rideRouteHighway.
  ///
  /// In en, this message translates to:
  /// **'highway'**
  String get rideRouteHighway;

  /// No description provided for @rideRouteClosedCourse.
  ///
  /// In en, this message translates to:
  /// **'closed course'**
  String get rideRouteClosedCourse;

  /// No description provided for @rideRouteStationary.
  ///
  /// In en, this message translates to:
  /// **'stationary'**
  String get rideRouteStationary;

  /// No description provided for @rideRecGpsNotSubscribed.
  ///
  /// In en, this message translates to:
  /// **'GPS: not subscribed -- pair the phone with the bike (bonded link required); it is retried on the next connection'**
  String get rideRecGpsNotSubscribed;

  /// No description provided for @rideRecGpsPairing.
  ///
  /// In en, this message translates to:
  /// **'GPS: pairing / subscribing...'**
  String get rideRecGpsPairing;

  /// No description provided for @rideRecGpsWaiting.
  ///
  /// In en, this message translates to:
  /// **'GPS: subscribed, waiting for data'**
  String get rideRecGpsWaiting;

  /// No description provided for @rideRecGpsNotOffered.
  ///
  /// In en, this message translates to:
  /// **'GPS: not offered by the firmware'**
  String get rideRecGpsNotOffered;

  /// No description provided for @rideRecGpsNone.
  ///
  /// In en, this message translates to:
  /// **'GPS: -'**
  String get rideRecGpsNone;

  /// No description provided for @rideRecGpsNotOk.
  ///
  /// In en, this message translates to:
  /// **' (not OK)'**
  String get rideRecGpsNotOk;

  /// No description provided for @rideRecGpsLine.
  ///
  /// In en, this message translates to:
  /// **'GPS: {fix}{notOk}   Sats: {sats}   {kmh} km/h   Lost/skipped: {lost}'**
  String rideRecGpsLine(
      String fix, String notOk, int sats, String kmh, int lost);

  /// No description provided for @rideRecSession.
  ///
  /// In en, this message translates to:
  /// **'Session: {id}'**
  String rideRecSession(String id);

  /// No description provided for @rideRecElapsed.
  ///
  /// In en, this message translates to:
  /// **'ELAPSED'**
  String get rideRecElapsed;

  /// No description provided for @rideRecStatPackets.
  ///
  /// In en, this message translates to:
  /// **'Packets'**
  String get rideRecStatPackets;

  /// No description provided for @rideRecStatLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get rideRecStatLost;

  /// No description provided for @rideRecStatLoss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get rideRecStatLoss;

  /// No description provided for @rideRecStatDecodeErrors.
  ///
  /// In en, this message translates to:
  /// **'Decode errors'**
  String get rideRecStatDecodeErrors;

  /// No description provided for @rideRecStatDisconnects.
  ///
  /// In en, this message translates to:
  /// **'Disconnects'**
  String get rideRecStatDisconnects;

  /// No description provided for @rideRecStatImuSamples.
  ///
  /// In en, this message translates to:
  /// **'IMU samples'**
  String get rideRecStatImuSamples;

  /// No description provided for @rideRecStatImuMissing.
  ///
  /// In en, this message translates to:
  /// **'IMU missing'**
  String get rideRecStatImuMissing;

  /// No description provided for @rideRecStatMtu.
  ///
  /// In en, this message translates to:
  /// **'MTU'**
  String get rideRecStatMtu;

  /// No description provided for @rideRecFirmwareOld.
  ///
  /// In en, this message translates to:
  /// **'Only version 2 telemetry packets received so far -- the connected device firmware may be outdated. Update it to get CAN health, ages and IMU data.'**
  String get rideRecFirmwareOld;

  /// No description provided for @rideRecNoPacketsYet.
  ///
  /// In en, this message translates to:
  /// **'No packets yet'**
  String get rideRecNoPacketsYet;

  /// No description provided for @rideRecLastPacketMs.
  ///
  /// In en, this message translates to:
  /// **'Last packet: {ms} ms ago'**
  String rideRecLastPacketMs(int ms);

  /// No description provided for @rideUpNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'not uploaded'**
  String get rideUpNotUploaded;

  /// No description provided for @rideUpNotUploadedNoServer.
  ///
  /// In en, this message translates to:
  /// **'not uploaded (no server configured)'**
  String get rideUpNotUploadedNoServer;

  /// No description provided for @rideUpUploading.
  ///
  /// In en, this message translates to:
  /// **'uploading...'**
  String get rideUpUploading;

  /// No description provided for @rideUpUploaded.
  ///
  /// In en, this message translates to:
  /// **'uploaded'**
  String get rideUpUploaded;

  /// No description provided for @rideUpUploadedAt.
  ///
  /// In en, this message translates to:
  /// **'uploaded ({time})'**
  String rideUpUploadedAt(String time);

  /// No description provided for @rideUpFailed.
  ///
  /// In en, this message translates to:
  /// **'failed: {reason}'**
  String rideUpFailed(String reason);

  /// No description provided for @rideUpUnknownError.
  ///
  /// In en, this message translates to:
  /// **'unknown error'**
  String get rideUpUnknownError;

  /// No description provided for @rideUpTipNoServer.
  ///
  /// In en, this message translates to:
  /// **'Set a server URL in Settings to enable uploads'**
  String get rideUpTipNoServer;

  /// No description provided for @rideUpTipRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry upload'**
  String get rideUpTipRetry;

  /// No description provided for @rideUpTipUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload to vehicle-server'**
  String get rideUpTipUpload;

  /// No description provided for @rideRecNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No recorded sessions yet.'**
  String get rideRecNoSessions;

  /// No description provided for @rideRecUnknownTime.
  ///
  /// In en, this message translates to:
  /// **'unknown time'**
  String get rideRecUnknownTime;

  /// No description provided for @rideRecSessionLine.
  ///
  /// In en, this message translates to:
  /// **'duration: {duration}  packets: {packets}  loss: {loss}'**
  String rideRecSessionLine(String duration, String packets, String loss);

  /// No description provided for @rideRecUploadLine.
  ///
  /// In en, this message translates to:
  /// **'upload: {status}'**
  String rideRecUploadLine(String status);

  /// No description provided for @rideRecRideSummary.
  ///
  /// In en, this message translates to:
  /// **'Ride summary'**
  String get rideRecRideSummary;

  /// No description provided for @rideRecBringup.
  ///
  /// In en, this message translates to:
  /// **'Bring-up check'**
  String get rideRecBringup;

  /// No description provided for @rideRecShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get rideRecShare;

  /// No description provided for @rideRecDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get rideRecDelete;

  /// No description provided for @rideRecCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get rideRecCancel;

  /// No description provided for @rideRecDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete session?'**
  String get rideRecDeleteTitle;

  /// No description provided for @rideRecDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes \"{id}\" and its recorded files.'**
  String rideRecDeleteBody(String id);

  /// No description provided for @rideRecSaved.
  ///
  /// In en, this message translates to:
  /// **'Session saved: {packets} packets, {loss}% loss'**
  String rideRecSaved(int packets, String loss);

  /// No description provided for @rideRecUploadFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {reason}'**
  String rideRecUploadFailedSnack(String reason);

  /// No description provided for @rideRecUploadComplete.
  ///
  /// In en, this message translates to:
  /// **'Upload complete.'**
  String get rideRecUploadComplete;

  /// No description provided for @rideVsigNoData.
  ///
  /// In en, this message translates to:
  /// **'Vehicle signals: no data'**
  String get rideVsigNoData;

  /// No description provided for @rideVsigLine.
  ///
  /// In en, this message translates to:
  /// **'Vehicle signals: {parts}{lost}'**
  String rideVsigLine(String parts, String lost);

  /// No description provided for @rideVsigFresh.
  ///
  /// In en, this message translates to:
  /// **'{n} fresh'**
  String rideVsigFresh(int n);

  /// No description provided for @rideVsigStale.
  ///
  /// In en, this message translates to:
  /// **'{n} stale'**
  String rideVsigStale(int n);

  /// No description provided for @rideVsigNrc.
  ///
  /// In en, this message translates to:
  /// **'{n} NRC'**
  String rideVsigNrc(int n);

  /// No description provided for @rideVsigSkipped.
  ///
  /// In en, this message translates to:
  /// **'{n} skipped'**
  String rideVsigSkipped(int n);

  /// No description provided for @rideVsigNever.
  ///
  /// In en, this message translates to:
  /// **'{n} never'**
  String rideVsigNever(int n);

  /// No description provided for @rideVsigUnknown.
  ///
  /// In en, this message translates to:
  /// **'{n} unknown'**
  String rideVsigUnknown(int n);

  /// No description provided for @rideVsigLostBlocks.
  ///
  /// In en, this message translates to:
  /// **'   Lost blocks: {n}'**
  String rideVsigLostBlocks(int n);

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get settingsSaving;

  /// No description provided for @settingsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDelete;

  /// No description provided for @settingsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get settingsAdd;

  /// No description provided for @settingsRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get settingsRetry;

  /// No description provided for @settingsDismiss.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsDismiss;

  /// No description provided for @settingsUnknownError.
  ///
  /// In en, this message translates to:
  /// **'unknown error'**
  String get settingsUnknownError;

  /// No description provided for @settingsSignalLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get settingsSignalLive;

  /// No description provided for @settingsSignalStale.
  ///
  /// In en, this message translates to:
  /// **'STALE'**
  String get settingsSignalStale;

  /// No description provided for @settingsSignalNoData.
  ///
  /// In en, this message translates to:
  /// **'NO DATA'**
  String get settingsSignalNoData;

  /// No description provided for @settingsSignalNotPolled.
  ///
  /// In en, this message translates to:
  /// **'NOT POLLED'**
  String get settingsSignalNotPolled;

  /// No description provided for @settingsSignalSkipped.
  ///
  /// In en, this message translates to:
  /// **'SKIPPED'**
  String get settingsSignalSkipped;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {username}'**
  String settingsSignedInAs(String username);

  /// No description provided for @settingsNoVehicles.
  ///
  /// In en, this message translates to:
  /// **'No vehicle is linked to this account.'**
  String get settingsNoVehicles;

  /// No description provided for @settingsDeviceTokenConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected with a device token'**
  String get settingsDeviceTokenConnected;

  /// No description provided for @settingsNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get settingsNotSignedIn;

  /// No description provided for @settingsAddVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle'**
  String get settingsAddVehicle;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get settingsSignIn;

  /// No description provided for @settingsVehicleId.
  ///
  /// In en, this message translates to:
  /// **'Vehicle ID'**
  String get settingsVehicleId;

  /// No description provided for @settingsClaimCode.
  ///
  /// In en, this message translates to:
  /// **'Claim code'**
  String get settingsClaimCode;

  /// No description provided for @settingsClaimInvalid.
  ///
  /// In en, this message translates to:
  /// **'The vehicle ID or code is not valid.'**
  String get settingsClaimInvalid;

  /// No description provided for @settingsRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in a moment.'**
  String get settingsRateLimited;

  /// No description provided for @settingsRateLimitedWait.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} s.'**
  String settingsRateLimitedWait(int seconds);

  /// No description provided for @settingsUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server.'**
  String get settingsUnreachable;

  /// No description provided for @settingsSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Session ended.'**
  String get settingsSessionEnded;

  /// No description provided for @settingsClaimFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add the vehicle: {detail}'**
  String settingsClaimFailed(String detail);

  /// No description provided for @settingsHosts.
  ///
  /// In en, this message translates to:
  /// **'Hosts (vehicle-server)'**
  String get settingsHosts;

  /// No description provided for @settingsAddHost.
  ///
  /// In en, this message translates to:
  /// **'Add host'**
  String get settingsAddHost;

  /// No description provided for @settingsEditHost.
  ///
  /// In en, this message translates to:
  /// **'Edit host'**
  String get settingsEditHost;

  /// No description provided for @settingsDeleteHost.
  ///
  /// In en, this message translates to:
  /// **'Delete host'**
  String get settingsDeleteHost;

  /// No description provided for @settingsHostsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the saved hosts.'**
  String get settingsHostsLoadFailed;

  /// No description provided for @settingsNoHosts.
  ///
  /// In en, this message translates to:
  /// **'No host configured yet: recording and sharing sessions work fully without one. Add a host to enable upload, rides, faults and the assistant.'**
  String get settingsNoHosts;

  /// No description provided for @settingsHostsHint.
  ///
  /// In en, this message translates to:
  /// **'The first host that answers is used, so put the local one first. Drag to reorder.'**
  String get settingsHostsHint;

  /// No description provided for @settingsCheckHosts.
  ///
  /// In en, this message translates to:
  /// **'Check hosts again'**
  String get settingsCheckHosts;

  /// No description provided for @settingsChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get settingsChecking;

  /// No description provided for @settingsDeleteHostTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete host?'**
  String get settingsDeleteHostTitle;

  /// No description provided for @settingsDeleteHostBody.
  ///
  /// In en, this message translates to:
  /// **'Removes \"{name}\" and its device token from this device.'**
  String settingsDeleteHostBody(String name);

  /// No description provided for @settingsHostActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get settingsHostActive;

  /// No description provided for @settingsTokenSet.
  ///
  /// In en, this message translates to:
  /// **'token set'**
  String get settingsTokenSet;

  /// No description provided for @settingsNoToken.
  ///
  /// In en, this message translates to:
  /// **'no token'**
  String get settingsNoToken;

  /// No description provided for @settingsCleartextShort.
  ///
  /// In en, this message translates to:
  /// **'http:// sends the token and ride data unencrypted. Use it only on a trusted local network.'**
  String get settingsCleartextShort;

  /// No description provided for @settingsCleartextLong.
  ///
  /// In en, this message translates to:
  /// **'Warning: http:// sends the token and ride data unencrypted. Use it only on a trusted local network; use https:// for any server reachable from outside.'**
  String get settingsCleartextLong;

  /// No description provided for @settingsHostName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get settingsHostName;

  /// No description provided for @settingsHostNameHint.
  ///
  /// In en, this message translates to:
  /// **'Bike (local Raspi)'**
  String get settingsHostNameHint;

  /// No description provided for @settingsHostUrl.
  ///
  /// In en, this message translates to:
  /// **'Server base URL'**
  String get settingsHostUrl;

  /// No description provided for @settingsHostToken.
  ///
  /// In en, this message translates to:
  /// **'Device token'**
  String get settingsHostToken;

  /// No description provided for @settingsEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get settingsEnterName;

  /// No description provided for @settingsEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter the server URL'**
  String get settingsEnterUrl;

  /// No description provided for @settingsUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get settingsUpload;

  /// No description provided for @settingsWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Upload only on Wi-Fi'**
  String get settingsWifiOnly;

  /// No description provided for @settingsWifiOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Session archives can be several MB; avoid mobile data by default.'**
  String get settingsWifiOnlyHint;

  /// No description provided for @settingsReadAnswers.
  ///
  /// In en, this message translates to:
  /// **'Read answers aloud'**
  String get settingsReadAnswers;

  /// No description provided for @settingsReadAnswersHint.
  ///
  /// In en, this message translates to:
  /// **'{assistant} reads the answer text aloud. On by default on the phone, off on web and desktop.'**
  String settingsReadAnswersHint(String assistant);

  /// No description provided for @settingsModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant model'**
  String get settingsModelTitle;

  /// No description provided for @settingsModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which model {assistant} uses to write its answers'**
  String settingsModelSubtitle(String assistant);

  /// No description provided for @settingsModelLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get settingsModelLoading;

  /// No description provided for @settingsModelUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Could not read it, tap to try again'**
  String get settingsModelUnreadable;

  /// No description provided for @settingsModelLocal.
  ///
  /// In en, this message translates to:
  /// **'Local model (default)'**
  String get settingsModelLocal;

  /// No description provided for @settingsModelConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Cloud providers need your consent. Give it and try again.'**
  String get settingsModelConsentRequired;

  /// No description provided for @settingsModelCloudDisabled.
  ///
  /// In en, this message translates to:
  /// **'Cloud providers are turned off on this server. The local model stays available.'**
  String get settingsModelCloudDisabled;

  /// No description provided for @settingsModelProviderError.
  ///
  /// In en, this message translates to:
  /// **'The provider returned an error. Check the key and the connection.'**
  String get settingsModelProviderError;

  /// No description provided for @settingsModelInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept the input.'**
  String get settingsModelInvalid;

  /// No description provided for @settingsModelInvalidDetail.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept the input: {detail}'**
  String settingsModelInvalidDetail(String detail);

  /// No description provided for @settingsModelNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This server version does not support model selection.'**
  String get settingsModelNotSupported;

  /// No description provided for @settingsModelFailed.
  ///
  /// In en, this message translates to:
  /// **'The action failed: {detail}'**
  String settingsModelFailed(String detail);

  /// No description provided for @settingsModelIntro.
  ///
  /// In en, this message translates to:
  /// **'{assistant} uses the local model on the server by default. You can pick another provider with your own API key.'**
  String settingsModelIntro(String assistant);

  /// No description provided for @settingsModelProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get settingsModelProvider;

  /// No description provided for @settingsModelConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsModelConnection;

  /// No description provided for @settingsModelBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Address (base URL)'**
  String get settingsModelBaseUrl;

  /// No description provided for @settingsModelKeyHelpCustom.
  ///
  /// In en, this message translates to:
  /// **'Enter the endpoint address and your API key, then tap Save.'**
  String get settingsModelKeyHelpCustom;

  /// No description provided for @settingsModelKeyHelp.
  ///
  /// In en, this message translates to:
  /// **'Paste your {provider} API key below, then tap Save. The key is sent once and is never shown again.'**
  String settingsModelKeyHelp(String provider);

  /// No description provided for @settingsModelSavedKey.
  ///
  /// In en, this message translates to:
  /// **'Saved key ••••{hint}'**
  String settingsModelSavedKey(String hint);

  /// No description provided for @settingsModelDeleteKey.
  ///
  /// In en, this message translates to:
  /// **'Delete key'**
  String get settingsModelDeleteKey;

  /// No description provided for @settingsModelNewKey.
  ///
  /// In en, this message translates to:
  /// **'New key (optional)'**
  String get settingsModelNewKey;

  /// No description provided for @settingsModelApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get settingsModelApiKey;

  /// No description provided for @settingsModelSendPosition.
  ///
  /// In en, this message translates to:
  /// **'Also send position data'**
  String get settingsModelSendPosition;

  /// No description provided for @settingsModelSendPositionHint.
  ///
  /// In en, this message translates to:
  /// **'While off, no position data goes to the provider.'**
  String get settingsModelSendPositionHint;

  /// No description provided for @settingsModelInsecureTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure connection required'**
  String get settingsModelInsecureTitle;

  /// No description provided for @settingsModelInsecureText.
  ///
  /// In en, this message translates to:
  /// **'The key can only be entered over a secure connection (HTTPS) or on the Pi with the command:\nvehicle-server user set-llm <user> --provider <id>'**
  String get settingsModelInsecureText;

  /// No description provided for @settingsModelTest.
  ///
  /// In en, this message translates to:
  /// **'Test the connection'**
  String get settingsModelTest;

  /// No description provided for @settingsModelTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get settingsModelTesting;

  /// No description provided for @settingsModelTestOk.
  ///
  /// In en, this message translates to:
  /// **'The connection works ({ms} ms).'**
  String settingsModelTestOk(int ms);

  /// No description provided for @settingsModelTestFailed.
  ///
  /// In en, this message translates to:
  /// **'The connection failed: {detail}'**
  String settingsModelTestFailed(String detail);

  /// No description provided for @settingsModelKeyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Key deleted.'**
  String get settingsModelKeyDeleted;

  /// No description provided for @settingsModelSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get settingsModelSaved;

  /// No description provided for @settingsModelDeleteKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the key?'**
  String get settingsModelDeleteKeyTitle;

  /// No description provided for @settingsModelDeleteKeyBody.
  ///
  /// In en, this message translates to:
  /// **'The saved key is deleted from the server. The assistant will not work with this provider.'**
  String get settingsModelDeleteKeyBody;

  /// No description provided for @settingsModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get settingsModelLabel;

  /// No description provided for @settingsModelListFailed.
  ///
  /// In en, this message translates to:
  /// **'The list could not be loaded, type the model name.'**
  String get settingsModelListFailed;

  /// No description provided for @settingsModelListLater.
  ///
  /// In en, this message translates to:
  /// **'The model list appears after you save the key; for now you can type the name.'**
  String get settingsModelListLater;

  /// No description provided for @settingsModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This provider is not available right now.'**
  String get settingsModelUnavailable;

  /// No description provided for @settingsModelCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud provider'**
  String get settingsModelCloud;

  /// No description provided for @settingsModelConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue with {provider}?'**
  String settingsModelConsentTitle(String provider);

  /// No description provided for @settingsModelConsentText.
  ///
  /// In en, this message translates to:
  /// **'Your question and the ride data the server computed are sent to {provider}. The cost is billed to your own {provider} account.'**
  String settingsModelConsentText(String provider);

  /// No description provided for @settingsModelAccept.
  ///
  /// In en, this message translates to:
  /// **'I accept'**
  String get settingsModelAccept;

  /// No description provided for @settingsAuthBadCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password.'**
  String get settingsAuthBadCredentials;

  /// No description provided for @settingsAuthUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is taken.'**
  String get settingsAuthUsernameTaken;

  /// No description provided for @settingsAuthInvalid.
  ///
  /// In en, this message translates to:
  /// **'The details were not accepted: {detail}'**
  String settingsAuthInvalid(String detail);

  /// No description provided for @settingsAuthInvalidFallback.
  ///
  /// In en, this message translates to:
  /// **'invalid input'**
  String get settingsAuthInvalidFallback;

  /// No description provided for @settingsAuthNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This server does not support account sign-in. Connect with a device token under Advanced.'**
  String get settingsAuthNotSupported;

  /// No description provided for @settingsAuthRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'The request failed: {detail}'**
  String settingsAuthRequestFailed(String detail);

  /// No description provided for @settingsLoginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get settingsLoginSignIn;

  /// No description provided for @settingsLoginRegister.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get settingsLoginRegister;

  /// No description provided for @settingsLoginSubRegister.
  ///
  /// In en, this message translates to:
  /// **'Create your account with the vehicle ID and the ownership code.'**
  String get settingsLoginSubRegister;

  /// No description provided for @settingsLoginSubSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your rides and notifications.'**
  String get settingsLoginSubSignIn;

  /// No description provided for @settingsLoginSavedHost.
  ///
  /// In en, this message translates to:
  /// **'Saved server'**
  String get settingsLoginSavedHost;

  /// No description provided for @settingsLoginServer.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get settingsLoginServer;

  /// No description provided for @settingsLoginUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get settingsLoginUsername;

  /// No description provided for @settingsLoginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsLoginPassword;

  /// No description provided for @settingsLoginHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get settingsLoginHaveAccount;

  /// No description provided for @settingsLoginAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced: connect with a device token'**
  String get settingsLoginAdvanced;

  /// No description provided for @settingsLoginConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get settingsLoginConnect;

  /// No description provided for @settingsLoginSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get settingsLoginSkip;

  /// No description provided for @settingsLoginEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter the server address.'**
  String get settingsLoginEnterUrl;

  /// No description provided for @settingsLoginInsecureUrl.
  ///
  /// In en, this message translates to:
  /// **'Insecure address: use https:// or a server on the local network.'**
  String get settingsLoginInsecureUrl;

  /// No description provided for @settingsLoginNeedCredentials.
  ///
  /// In en, this message translates to:
  /// **'Username and password are required.'**
  String get settingsLoginNeedCredentials;

  /// No description provided for @settingsLoginNeedVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle ID and claim code are required.'**
  String get settingsLoginNeedVehicle;

  /// No description provided for @settingsLoginNeedToken.
  ///
  /// In en, this message translates to:
  /// **'Enter the device token.'**
  String get settingsLoginNeedToken;

  /// No description provided for @settingsLoginSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Session ended. Please sign in again.'**
  String get settingsLoginSessionEnded;
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
