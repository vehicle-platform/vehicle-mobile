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

  @override
  String get assistantGreeting =>
      'Hello, I am the Ride Assistant. What would you like to know?';

  @override
  String get assistantExample1 => 'How was my last ride?';

  @override
  String get assistantExample2 => 'Summary of the last ride';

  @override
  String get assistantExample3 => 'Any recorded faults?';

  @override
  String get assistantHint => 'Type a question';

  @override
  String get assistantHintListening => 'Listening...';

  @override
  String get assistantSend => 'Send';

  @override
  String get assistantClear => 'Clear conversation';

  @override
  String assistantRideChip(String id) {
    return 'Ride $id';
  }

  @override
  String get assistantStepReading => 'Reading the data ...';

  @override
  String assistantStepReadingRide(String id) {
    return 'Reading ride $id ...';
  }

  @override
  String get assistantSourceLlm => 'Assistant';

  @override
  String get assistantSourceTemplate => 'Verified from data';

  @override
  String get assistantSourceUnsupported => 'Could not answer';

  @override
  String get assistantSourceError => 'Error';

  @override
  String get assistantModelTemplate => 'Template answer (no model)';

  @override
  String get assistantModelNone => 'Not answered (no model)';

  @override
  String assistantModelChipLabel(String text) {
    return 'Assistant model: $text';
  }

  @override
  String get assistantComputedBy => 'computed by ';

  @override
  String get assistantArguments => 'Arguments';

  @override
  String get assistantResult => 'Result';

  @override
  String get assistantResultEmpty => '(empty)';

  @override
  String assistantItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String assistantMoreItems(int count) {
    return '+$count more';
  }

  @override
  String get assistantTruncated => 'truncated';

  @override
  String get assistantFailSettings => 'Could not read the host settings.';

  @override
  String get assistantFailNoHost =>
      'No host with a device token is configured. Add one in Settings > Hosts.';

  @override
  String assistantFailUnauthorized(String host) {
    return 'The device token was rejected by \"$host\". Check the token in Settings > Hosts.';
  }

  @override
  String assistantFailInvalid(String message) {
    return 'The server rejected the message: $message';
  }

  @override
  String get assistantFailRateLimited => 'Rate limited. Try again shortly.';

  @override
  String assistantFailRateLimitedIn(int seconds) {
    return 'Rate limited. Try again in $seconds s.';
  }

  @override
  String assistantFailDisabled(String host) {
    return 'The assistant is disabled on \"$host\".';
  }

  @override
  String assistantFailUnreachable(String host) {
    return 'Host unreachable: \"$host\".';
  }

  @override
  String assistantFailFailed(String message) {
    return 'Request failed: $message';
  }

  @override
  String get assistantFailUnknown => 'unknown error';

  @override
  String get assistantTheHost => 'the host';

  @override
  String get assistantVoiceInitTimeout =>
      'Speech recognition is not available. You can type the question.';

  @override
  String get assistantVoiceNoSpeech => 'I did not hear you. Try again?';

  @override
  String get assistantVoiceUnavailable =>
      'Speech recognition is not available right now. You can type the question.';

  @override
  String get assistantVoicePermission =>
      'Microphone permission was not granted or this device has no speech recognition. You can allow it in the settings or type the question.';

  @override
  String get assistantVoiceLanguage =>
      'Speech recognition for this language is not installed on this device. You can type the question.';

  @override
  String get assistantVoiceNetwork =>
      'Speech recognition needs an internet connection.';

  @override
  String get assistantRouteIntercom => 'Intercom connected';

  @override
  String get assistantRoutePhone => 'Phone microphone';

  @override
  String get assistantMicStop => 'Stop listening';

  @override
  String get assistantMicSpeaking => 'Stop reading and speak';

  @override
  String get assistantMicStart => 'Ask by voice';

  @override
  String get assistantClose => 'Close';

  @override
  String get assistantHoldToTalk => 'Hold to talk';

  @override
  String get assistantReleaseToSend => 'Release to send';

  @override
  String get assistantPreparing => 'Preparing the microphone ...';

  @override
  String get formatToday => 'Today';

  @override
  String get formatYesterday => 'Yesterday';

  @override
  String get garageNotificationsTitle => 'Notifications';

  @override
  String get garageNotificationTitle => 'Notification';

  @override
  String get garageBellTooltip => 'Notifications';

  @override
  String garageBellTooltipUnread(int count) {
    return 'Notifications ($count unread)';
  }

  @override
  String get garageSeverityCritical => 'Critical';

  @override
  String get garageSeverityWarning => 'Warning';

  @override
  String get garageSeverityInfo => 'Info';

  @override
  String get garageDayNoDate => 'No date';

  @override
  String get garageEmptyTitle => 'No notifications yet';

  @override
  String get garageEmptyHint => 'Ride summaries and alerts appear here.';

  @override
  String get garageUnread => 'Unread';

  @override
  String get garageOpenRide => 'Open ride';

  @override
  String garageAskAssistant(String assistant) {
    return 'Ask $assistant';
  }

  @override
  String garageAskQuestion(String title) {
    return 'What can you tell me about the notification \"$title\"?';
  }

  @override
  String get garageFaultsTitle => 'Faults';

  @override
  String get garageFaultsLoading => 'Loading faults...';

  @override
  String get garageFaultsNoServer =>
      'No vehicle-server configured. Add a host with its device token in Settings.';

  @override
  String get garageFaultsRetry => 'Retry';

  @override
  String get garageFaultsEmpty => 'The host lists no faults.';

  @override
  String get garageAnnounceAdviseStop =>
      'Stop in a safe place and have the engine checked.';

  @override
  String garageAnnounceFault(String title) {
    return 'High-priority warning: $title. Stop in a safe place and have the engine checked.';
  }

  @override
  String get logbookRideHistoryTitle => 'Ride history';

  @override
  String get logbookRideSummaryTitle => 'Ride summary';

  @override
  String get logbookBringupTitle => 'Bring-up check';

  @override
  String get logbookRefresh => 'Refresh';

  @override
  String get logbookRetry => 'Retry';

  @override
  String get logbookOpenSettings => 'Open Settings';

  @override
  String get logbookAskAssistant => 'Ask the assistant';

  @override
  String get logbookLoadingRides => 'Loading rides...';

  @override
  String get logbookLoadingSummary => 'Loading ride summary...';

  @override
  String get logbookLoadingBringup => 'Loading bring-up check...';

  @override
  String get logbookNoServer =>
      'No vehicle-server configured. Set the server URL and API token in Settings.';

  @override
  String get logbookCleartextWarning =>
      'Warning: http:// sends the API token and ride data unencrypted. Use it only on a trusted local network; use https:// for any server reachable from outside.';

  @override
  String get logbookAllRides => 'All rides';

  @override
  String logbookRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get logbookNoRidesInRange => 'No rides in this range.';

  @override
  String logbookSkippedHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions without a stored summary skipped.',
      one: '1 session without a stored summary skipped.',
    );
    return '$_temp0';
  }

  @override
  String get logbookDateRange => 'Date range';

  @override
  String get logbookChangeRange => 'Change range';

  @override
  String get logbookClear => 'Clear';

  @override
  String get logbookColumns => 'Columns';

  @override
  String get logbookUpToTwo => 'up to two';

  @override
  String logbookRideCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rides',
      one: '1 ride',
    );
    return '$_temp0';
  }

  @override
  String logbookSkippedCount(int count) {
    return '$count skipped';
  }

  @override
  String get logbookUnknownTime => 'unknown time';

  @override
  String get logbookSignals => 'Signals';

  @override
  String get logbookPerGear => 'Per-gear signals';

  @override
  String get logbookBinned => 'Binned signals';

  @override
  String get logbookCoverage => 'Coverage';

  @override
  String get logbookHealthWindows => 'Health windows';

  @override
  String get logbookNoSummary => 'No stored ride summary for this session.';

  @override
  String logbookDefsMismatch(String names) {
    return 'Decoded with other defs bin edges: $names.';
  }

  @override
  String logbookRideDefinition(String value) {
    return 'ride $value';
  }

  @override
  String logbookDefsVersion(String value) {
    return 'defs $value';
  }

  @override
  String get logbookNoSignals => 'No stored signals in this ride summary.';

  @override
  String logbookGear(int n) {
    return 'Gear $n';
  }

  @override
  String get logbookNoGears => 'No stored gears.';

  @override
  String logbookAxisUnsupported(int n) {
    return '$n-axis summaries are not shown on the phone yet.';
  }

  @override
  String logbookTotalOutside(String total, String outside) {
    return 'total $total · outside $outside';
  }

  @override
  String logbookNotAvailable(int n) {
    return 'Not available ($n)';
  }

  @override
  String logbookPendingInputs(String list) {
    return 'pending: $list';
  }

  @override
  String logbookMissingInputs(String list) {
    return 'missing: $list';
  }

  @override
  String logbookColumnsAxis(String input, String unit) {
    return 'columns: $input [$unit]';
  }

  @override
  String logbookRowsAxis(String input, String unit) {
    return 'rows: $input [$unit]';
  }

  @override
  String get logbookSession => 'Session';

  @override
  String get logbookBringupUnsupported =>
      'this server has no bring-up check (needs vehicle-server with the bring-up route, server#50)';

  @override
  String get logbookBringupUnauthorized =>
      'Unauthorized: check the API token in Settings.';

  @override
  String get logbookBringupNotFound =>
      'the server does not have this session (upload it first)';

  @override
  String get logbookBringupInvalid => 'invalid request';

  @override
  String get logbookBringupUnavailable => 'server unavailable';

  @override
  String get logbookBringupFailed => 'request failed';

  @override
  String get logbookSettingsReadFailed => 'Could not read the server settings.';

  @override
  String get logbookNoBringupAnswer =>
      'The server returned no bring-up answer.';

  @override
  String get logbookNoChecks => 'The server returned no checks for this gate.';

  @override
  String get logbookChecks => 'Checks';

  @override
  String logbookManualPending(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count manual checks pending: $list',
      one: '1 manual check pending: $list',
    );
    return '$_temp0';
  }

  @override
  String logbookWarningsList(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings: $list',
      one: '1 warning: $list',
    );
    return '$_temp0';
  }

  @override
  String get logbookBringupLegend =>
      'manual = you judge it at the bike; unknown = the session has no data for it.';

  @override
  String get logbookMeasured => 'Measured';

  @override
  String get logbookExpected => 'Expected';

  @override
  String get logbookSource => 'Source';

  @override
  String get logbookNote => 'Note';

  @override
  String get logbookWindowsLoading => 'Loading window instances...';

  @override
  String get logbookWindowsMissingReport =>
      'No window instances in this report (older server, or run `vehicle-server derive <id>` on the server).';

  @override
  String get logbookWindowsUnavailable => 'Unavailable.';

  @override
  String get logbookWindowsNone => 'No window instances stored.';

  @override
  String logbookWindowsCounts(int instances, int qualifying) {
    return '$instances instances, $qualifying qualifying';
  }

  @override
  String get logbookColStart => 'Start';

  @override
  String get logbookColEnd => 'End';

  @override
  String get logbookColDuration => 'Duration';

  @override
  String get logbookColCloseReason => 'Close reason';

  @override
  String get logbookColQualifies => 'Qualifies';

  @override
  String get logbookColFirst => 'First';

  @override
  String get logbookYes => 'yes';

  @override
  String get logbookNo => 'no';

  @override
  String get logbookFirstMark => 'first';

  @override
  String get quantityRideDistance => 'Distance';

  @override
  String get quantityRideTime => 'Ride time';

  @override
  String get quantityRideStopCount => 'Stops';

  @override
  String get quantityRideIdleTime => 'Idle time';

  @override
  String get quantityRideWarmupTime => 'Warm-up time';

  @override
  String get quantityRideEndCoolantTemp => 'Coolant at end';

  @override
  String get quantityRideStartCoolantTemp => 'Coolant at start';

  @override
  String get quantityRideFuelConsumption => 'Fuel consumption';

  @override
  String get quantityRideFuelUsed => 'Fuel used';

  @override
  String get quantityRideRestVoltage => 'Battery at rest';

  @override
  String get quantityRideShiftCount => 'Gear shifts';

  @override
  String get quantityRideAggressiveness => 'Riding intensity';

  @override
  String get logbookCompare => 'Compare';

  @override
  String get logbookCompareTitle => 'Compare rides';

  @override
  String get logbookCompareHint =>
      'Pick up to two more quantities to show on every ride.';

  @override
  String get logbookRiderQuantities => 'Ride quantities';

  @override
  String get logbookAllSignals => 'All signals';

  @override
  String get logbookCompareDone => 'Done';

  @override
  String get rideLiveOpenRecord => 'Open the Record screen';

  @override
  String get rideSynthTitle => 'SYNTHETIC DATA';

  @override
  String get rideSynthText =>
      'The node is generating mock values. Nothing shown here comes from the bike.';

  @override
  String get rideRecordCta => 'RECORD A SESSION';

  @override
  String get rideStatusLabel => 'Status';

  @override
  String get rideConnected => 'Connected';

  @override
  String get rideDisconnected => 'Disconnected';

  @override
  String get rideNotConnected => 'Not connected';

  @override
  String get rideWaitingFirstPacket => 'Waiting for the first packet';

  @override
  String rideLastPacketAgoSub(String age) {
    return 'Last packet $age ago';
  }

  @override
  String get rideScanningTitle => 'Scanning...';

  @override
  String get rideLookingForBike => 'Looking for the bike';

  @override
  String get rideTapConnect => 'Tap Connect to scan for the bike';

  @override
  String get rideDisconnect => 'Disconnect';

  @override
  String get rideConnect => 'Connect';

  @override
  String get rideScanning => 'Scanning';

  @override
  String rideBleDevice(String device) {
    return 'BLE $device';
  }

  @override
  String get rideBleConnected => 'BLE connected';

  @override
  String get rideBleDisconnected => 'BLE disconnected';

  @override
  String get rideEcuPresent => 'ECU present';

  @override
  String get rideEcuNotFound => 'ECU not found';

  @override
  String get rideEcuUnknown => 'ECU --';

  @override
  String get rideCanUnknown => 'CAN --';

  @override
  String get ridePollerOff => 'Poller off';

  @override
  String get rideForeignLatched => 'Foreign tester latched';

  @override
  String get rideBusOffLatched => 'Bus-off latched';

  @override
  String get rideLatchesClear => 'Latches clear';

  @override
  String get rideSyntheticData => 'Synthetic data';

  @override
  String get rideImuActive => 'IMU active';

  @override
  String get rideImuInactive => 'IMU inactive';

  @override
  String get rideImuUnknown => 'IMU --';

  @override
  String get rideCanNa => 'CAN n/a';

  @override
  String get rideCanRunning => 'CAN running';

  @override
  String get rideCanErrorWarning => 'CAN error warning';

  @override
  String get rideCanBusOff => 'CAN bus-off';

  @override
  String get rideCanStopped => 'CAN stopped';

  @override
  String get rideCanNotInstalled => 'CAN not installed';

  @override
  String get rideGpsNone => 'GPS --';

  @override
  String get rideGpsNotOffered => 'GPS not offered';

  @override
  String get rideGpsPairing => 'GPS pairing...';

  @override
  String get rideGpsPairPhone => 'GPS: pair phone with bike';

  @override
  String get rideGpsWaiting => 'GPS waiting for data';

  @override
  String rideGpsFix(String fix, int sats) {
    return 'GPS $fix · $sats sats';
  }

  @override
  String get rideSigLive => 'live';

  @override
  String get rideSigPolled => 'polled';

  @override
  String get rideSigCandidates => 'candidates';

  @override
  String get rideFilterAll => 'All';

  @override
  String get rideFilterPolled => 'Polled';

  @override
  String get rideFilterCandidates => 'Candidates';

  @override
  String rideGroupLive(int live, int total) {
    return '$live / $total live';
  }

  @override
  String ridePollEvery(int ms) {
    return 'Poll every $ms ms';
  }

  @override
  String rideAgeDetail(String age, String detail) {
    return 'Age $age · $detail';
  }

  @override
  String get rideNotPolled => 'Not polled';

  @override
  String get rideReportedByNode => 'Reported by the node';

  @override
  String get rideDiagLink => 'Link';

  @override
  String get rideDiagBle => 'BLE';

  @override
  String get rideDiagDevice => 'Device';

  @override
  String get rideDiagAttMtu => 'ATT MTU';

  @override
  String get rideDiagRequestedMtu => 'Requested MTU';

  @override
  String get rideDiagPacketVersion => 'Packet version';

  @override
  String get rideDiagLastPacket => 'Last packet';

  @override
  String rideDiagAgoSuffix(String age) {
    return '$age ago';
  }

  @override
  String get rideDiagDeviceTime => 'Device time';

  @override
  String get rideDiagPackets => 'Packets';

  @override
  String get rideDiagReceived => 'Received';

  @override
  String get rideDiagLostGaps => 'Lost (sequence gaps)';

  @override
  String get rideDiagLoss => 'Loss';

  @override
  String get rideDiagRejectedVersion => 'Rejected (version)';

  @override
  String get rideDiagRejectedSize => 'Rejected (size)';

  @override
  String get rideDiagCanBus => 'Vehicle CAN bus';

  @override
  String get rideDiagBusState => 'Bus state';

  @override
  String get rideDiagTxErrors => 'TX errors';

  @override
  String get rideDiagRxErrors => 'RX errors';

  @override
  String get rideDiagBusOffEvents => 'Bus-off events';

  @override
  String get rideDiagUnansweredDids => 'Unanswered DIDs';

  @override
  String get rideDiagPollerEnabled => 'Poller enabled';

  @override
  String get rideDiagForeignLatched => 'Foreign tester latched';

  @override
  String get rideDiagBusOffLatched => 'Bus-off latched';

  @override
  String get rideDiagSynthetic => 'Synthetic data';

  @override
  String get rideYes => 'yes';

  @override
  String get rideNo => 'no';

  @override
  String rideDiagCanNeeds(String version) {
    return 'CAN health needs a version $version or newer packet.';
  }

  @override
  String get rideDiagTester => 'Tester (diagnostic poller)';

  @override
  String get rideDiagStepGapMax => 'Step gap, max';

  @override
  String get rideDiagStepGapOver => 'Step gap, over limit';

  @override
  String get rideDiagRoundTrip => 'Round trip, rotating DID';

  @override
  String get rideDiagDid => 'DID';

  @override
  String get rideDiagMin => 'Min';

  @override
  String get rideDiagMax => 'Max';

  @override
  String get rideDiagMean => 'Mean';

  @override
  String get rideDiagSamples => 'Samples';

  @override
  String get rideDiagNrc78 => 'NRC 0x78 (pending)';

  @override
  String rideDiagTesterNeeds(String version) {
    return 'Tester stats need a version $version packet.';
  }

  @override
  String get rideRecTabRecord => 'Record';

  @override
  String get rideRecTabSessions => 'Sessions';

  @override
  String get rideRecServerRides => 'Server rides';

  @override
  String rideRecRunning(String duration) {
    return 'REC $duration';
  }

  @override
  String get rideRecKeepOn =>
      'Keep this screen on and the app in the foreground while recording. Android may kill the BLE connection if the app is backgrounded or killed -- there is no foreground service yet.';

  @override
  String get rideRecStop => 'STOP RECORDING';

  @override
  String get rideRecStart => 'START RECORDING';

  @override
  String get rideRecMetadata => 'Session metadata';

  @override
  String get rideRecRiderName => 'Rider name';

  @override
  String get rideRecRiderWeight => 'Rider weight (kg)';

  @override
  String get rideRecExtraLoad => 'Extra load (kg)';

  @override
  String get rideRecAmbientTemp => 'Ambient temp (°C)';

  @override
  String get rideRecWeather => 'Weather';

  @override
  String get rideRecTireFront => 'Tire pressure front (bar)';

  @override
  String get rideRecTireRear => 'Tire pressure rear (bar)';

  @override
  String get rideRecFuel => 'Fuel level (e.g. full, 1/2, reserve)';

  @override
  String get rideRecVehicleConfig => 'Vehicle config (gearing/exhaust/filter)';

  @override
  String get rideRecCondition => 'Condition label (healthy or fault type)';

  @override
  String get rideRecRouteType => 'Route type';

  @override
  String get rideRecNote => 'Note';

  @override
  String get rideWeatherDry => 'dry';

  @override
  String get rideWeatherWet => 'wet';

  @override
  String get rideWeatherUnknown => 'unknown';

  @override
  String get rideRouteUrban => 'urban';

  @override
  String get rideRouteRural => 'rural';

  @override
  String get rideRouteHighway => 'highway';

  @override
  String get rideRouteClosedCourse => 'closed course';

  @override
  String get rideRouteStationary => 'stationary';

  @override
  String get rideRecGpsNotSubscribed =>
      'GPS: not subscribed -- pair the phone with the bike (bonded link required); it is retried on the next connection';

  @override
  String get rideRecGpsPairing => 'GPS: pairing / subscribing...';

  @override
  String get rideRecGpsWaiting => 'GPS: subscribed, waiting for data';

  @override
  String get rideRecGpsNotOffered => 'GPS: not offered by the firmware';

  @override
  String get rideRecGpsNone => 'GPS: -';

  @override
  String get rideRecGpsNotOk => ' (not OK)';

  @override
  String rideRecGpsLine(
      String fix, String notOk, int sats, String kmh, int lost) {
    return 'GPS: $fix$notOk   Sats: $sats   $kmh km/h   Lost/skipped: $lost';
  }

  @override
  String rideRecSession(String id) {
    return 'Session: $id';
  }

  @override
  String get rideRecElapsed => 'ELAPSED';

  @override
  String get rideRecStatPackets => 'Packets';

  @override
  String get rideRecStatLost => 'Lost';

  @override
  String get rideRecStatLoss => 'Loss';

  @override
  String get rideRecStatDecodeErrors => 'Decode errors';

  @override
  String get rideRecStatDisconnects => 'Disconnects';

  @override
  String get rideRecStatImuSamples => 'IMU samples';

  @override
  String get rideRecStatImuMissing => 'IMU missing';

  @override
  String get rideRecStatMtu => 'MTU';

  @override
  String get rideRecFirmwareOld =>
      'Only version 2 telemetry packets received so far -- the connected device firmware may be outdated. Update it to get CAN health, ages and IMU data.';

  @override
  String get rideRecNoPacketsYet => 'No packets yet';

  @override
  String rideRecLastPacketMs(int ms) {
    return 'Last packet: $ms ms ago';
  }

  @override
  String get rideUpNotUploaded => 'not uploaded';

  @override
  String get rideUpNotUploadedNoServer => 'not uploaded (no server configured)';

  @override
  String get rideUpUploading => 'uploading...';

  @override
  String get rideUpUploaded => 'uploaded';

  @override
  String rideUpUploadedAt(String time) {
    return 'uploaded ($time)';
  }

  @override
  String rideUpFailed(String reason) {
    return 'failed: $reason';
  }

  @override
  String get rideUpUnknownError => 'unknown error';

  @override
  String get rideUpTipNoServer =>
      'Set a server URL in Settings to enable uploads';

  @override
  String get rideUpTipRetry => 'Retry upload';

  @override
  String get rideUpTipUpload => 'Upload to vehicle-server';

  @override
  String get rideRecNoSessions => 'No recorded sessions yet.';

  @override
  String get rideRecUnknownTime => 'unknown time';

  @override
  String rideRecSessionLine(String duration, String packets, String loss) {
    return 'duration: $duration  packets: $packets  loss: $loss';
  }

  @override
  String rideRecUploadLine(String status) {
    return 'upload: $status';
  }

  @override
  String get rideRecRideSummary => 'Ride summary';

  @override
  String get rideRecBringup => 'Bring-up check';

  @override
  String get rideRecShare => 'Share';

  @override
  String get rideRecDelete => 'Delete';

  @override
  String get rideRecCancel => 'Cancel';

  @override
  String get rideRecDeleteTitle => 'Delete session?';

  @override
  String rideRecDeleteBody(String id) {
    return 'This permanently deletes \"$id\" and its recorded files.';
  }

  @override
  String rideRecSaved(int packets, String loss) {
    return 'Session saved: $packets packets, $loss% loss';
  }

  @override
  String rideRecUploadFailedSnack(String reason) {
    return 'Upload failed: $reason';
  }

  @override
  String get rideRecUploadComplete => 'Upload complete.';

  @override
  String get rideVsigNoData => 'Vehicle signals: no data';

  @override
  String rideVsigLine(String parts, String lost) {
    return 'Vehicle signals: $parts$lost';
  }

  @override
  String rideVsigFresh(int n) {
    return '$n fresh';
  }

  @override
  String rideVsigStale(int n) {
    return '$n stale';
  }

  @override
  String rideVsigNrc(int n) {
    return '$n NRC';
  }

  @override
  String rideVsigSkipped(int n) {
    return '$n skipped';
  }

  @override
  String rideVsigNever(int n) {
    return '$n never';
  }

  @override
  String rideVsigUnknown(int n) {
    return '$n unknown';
  }

  @override
  String rideVsigLostBlocks(int n) {
    return '   Lost blocks: $n';
  }

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsSaving => 'Saving...';

  @override
  String get settingsDelete => 'Delete';

  @override
  String get settingsAdd => 'Add';

  @override
  String get settingsRetry => 'Try again';

  @override
  String get settingsDismiss => 'Cancel';

  @override
  String get settingsUnknownError => 'unknown error';

  @override
  String get settingsSignalLive => 'LIVE';

  @override
  String get settingsSignalStale => 'STALE';

  @override
  String get settingsSignalNoData => 'NO DATA';

  @override
  String get settingsSignalNotPolled => 'NOT POLLED';

  @override
  String get settingsSignalSkipped => 'SKIPPED';

  @override
  String get settingsAccount => 'Account';

  @override
  String settingsSignedInAs(String username) {
    return 'Signed in as $username';
  }

  @override
  String get settingsNoVehicles => 'No vehicle is linked to this account.';

  @override
  String get settingsDeviceTokenConnected => 'Connected with a device token';

  @override
  String get settingsNotSignedIn => 'Not signed in';

  @override
  String get settingsAddVehicle => 'Add vehicle';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignIn => 'Sign in';

  @override
  String get settingsVehicleId => 'Vehicle ID';

  @override
  String get settingsClaimCode => 'Claim code';

  @override
  String get settingsClaimInvalid => 'The vehicle ID or code is not valid.';

  @override
  String get settingsRateLimited => 'Too many attempts. Try again in a moment.';

  @override
  String settingsRateLimitedWait(int seconds) {
    return 'Too many attempts. Try again in $seconds s.';
  }

  @override
  String get settingsUnreachable => 'Could not reach the server.';

  @override
  String get settingsSessionEnded => 'Session ended.';

  @override
  String settingsClaimFailed(String detail) {
    return 'Could not add the vehicle: $detail';
  }

  @override
  String get settingsHosts => 'Hosts (vehicle-server)';

  @override
  String get settingsAddHost => 'Add host';

  @override
  String get settingsEditHost => 'Edit host';

  @override
  String get settingsDeleteHost => 'Delete host';

  @override
  String get settingsHostsLoadFailed => 'Could not read the saved hosts.';

  @override
  String get settingsNoHosts =>
      'No host configured yet: recording and sharing sessions work fully without one. Add a host to enable upload, rides, faults and the assistant.';

  @override
  String get settingsHostsHint =>
      'The first host that answers is used, so put the local one first. Drag to reorder.';

  @override
  String get settingsCheckHosts => 'Check hosts again';

  @override
  String get settingsChecking => 'Checking...';

  @override
  String get settingsDeleteHostTitle => 'Delete host?';

  @override
  String settingsDeleteHostBody(String name) {
    return 'Removes \"$name\" and its device token from this device.';
  }

  @override
  String get settingsHostActive => 'active';

  @override
  String get settingsTokenSet => 'token set';

  @override
  String get settingsNoToken => 'no token';

  @override
  String get settingsCleartextShort =>
      'http:// sends the token and ride data unencrypted. Use it only on a trusted local network.';

  @override
  String get settingsCleartextLong =>
      'Warning: http:// sends the token and ride data unencrypted. Use it only on a trusted local network; use https:// for any server reachable from outside.';

  @override
  String get settingsHostName => 'Name';

  @override
  String get settingsHostNameHint => 'Bike (local Raspi)';

  @override
  String get settingsHostUrl => 'Server base URL';

  @override
  String get settingsHostToken => 'Device token';

  @override
  String get settingsEnterName => 'Enter a name';

  @override
  String get settingsEnterUrl => 'Enter the server URL';

  @override
  String get settingsUpload => 'Upload';

  @override
  String get settingsWifiOnly => 'Upload only on Wi-Fi';

  @override
  String get settingsWifiOnlyHint =>
      'Session archives can be several MB; avoid mobile data by default.';

  @override
  String get settingsReadAnswers => 'Read answers aloud';

  @override
  String settingsReadAnswersHint(String assistant) {
    return '$assistant reads the answer text aloud. On by default on the phone, off on web and desktop.';
  }

  @override
  String get settingsModelTitle => 'Assistant model';

  @override
  String settingsModelSubtitle(String assistant) {
    return 'Which model $assistant uses to write its answers';
  }

  @override
  String get settingsModelLoading => 'Loading...';

  @override
  String get settingsModelUnreadable => 'Could not read it, tap to try again';

  @override
  String get settingsModelLocal => 'Local model (default)';

  @override
  String get settingsModelConsentRequired =>
      'Cloud providers need your consent. Give it and try again.';

  @override
  String get settingsModelCloudDisabled =>
      'Cloud providers are turned off on this server. The local model stays available.';

  @override
  String get settingsModelProviderError =>
      'The provider returned an error. Check the key and the connection.';

  @override
  String get settingsModelInvalid => 'The server did not accept the input.';

  @override
  String settingsModelInvalidDetail(String detail) {
    return 'The server did not accept the input: $detail';
  }

  @override
  String get settingsModelNotSupported =>
      'This server version does not support model selection.';

  @override
  String settingsModelFailed(String detail) {
    return 'The action failed: $detail';
  }

  @override
  String settingsModelIntro(String assistant) {
    return '$assistant uses the local model on the server by default. You can pick another provider with your own API key.';
  }

  @override
  String get settingsModelProvider => 'Provider';

  @override
  String get settingsModelConnection => 'Connection';

  @override
  String get settingsModelBaseUrl => 'Address (base URL)';

  @override
  String get settingsModelKeyHelpCustom =>
      'Enter the endpoint address and your API key, then tap Save.';

  @override
  String settingsModelKeyHelp(String provider) {
    return 'Paste your $provider API key below, then tap Save. The key is sent once and is never shown again.';
  }

  @override
  String settingsModelSavedKey(String hint) {
    return 'Saved key ••••$hint';
  }

  @override
  String get settingsModelDeleteKey => 'Delete key';

  @override
  String get settingsModelNewKey => 'New key (optional)';

  @override
  String get settingsModelApiKey => 'API key';

  @override
  String get settingsModelSendPosition => 'Also send position data';

  @override
  String get settingsModelSendPositionHint =>
      'While off, no position data goes to the provider.';

  @override
  String get settingsModelInsecureTitle => 'Secure connection required';

  @override
  String get settingsModelInsecureText =>
      'The key can only be entered over a secure connection (HTTPS) or on the Pi with the command:\nvehicle-server user set-llm <user> --provider <id>';

  @override
  String get settingsModelTest => 'Test the connection';

  @override
  String get settingsModelTesting => 'Testing...';

  @override
  String settingsModelTestOk(int ms) {
    return 'The connection works ($ms ms).';
  }

  @override
  String settingsModelTestFailed(String detail) {
    return 'The connection failed: $detail';
  }

  @override
  String get settingsModelKeyDeleted => 'Key deleted.';

  @override
  String get settingsModelSaved => 'Saved.';

  @override
  String get settingsModelDeleteKeyTitle => 'Delete the key?';

  @override
  String get settingsModelDeleteKeyBody =>
      'The saved key is deleted from the server. The assistant will not work with this provider.';

  @override
  String get settingsModelLabel => 'Model';

  @override
  String get settingsModelListFailed =>
      'The list could not be loaded, type the model name.';

  @override
  String get settingsModelListLater =>
      'The model list appears after you save the key; for now you can type the name.';

  @override
  String get settingsModelUnavailable =>
      'This provider is not available right now.';

  @override
  String get settingsModelCloud => 'Cloud provider';

  @override
  String settingsModelConsentTitle(String provider) {
    return 'Continue with $provider?';
  }

  @override
  String settingsModelConsentText(String provider) {
    return 'Your question and the ride data the server computed are sent to $provider. The cost is billed to your own $provider account.';
  }

  @override
  String get settingsModelAccept => 'I accept';

  @override
  String get settingsAuthBadCredentials => 'Wrong username or password.';

  @override
  String get settingsAuthUsernameTaken => 'That username is taken.';

  @override
  String settingsAuthInvalid(String detail) {
    return 'The details were not accepted: $detail';
  }

  @override
  String get settingsAuthInvalidFallback => 'invalid input';

  @override
  String get settingsAuthNotSupported =>
      'This server does not support account sign-in. Connect with a device token under Advanced.';

  @override
  String settingsAuthRequestFailed(String detail) {
    return 'The request failed: $detail';
  }

  @override
  String get settingsLoginSignIn => 'Sign in';

  @override
  String get settingsLoginRegister => 'Create account';

  @override
  String get settingsLoginSubRegister =>
      'Create your account with the vehicle ID and the ownership code.';

  @override
  String get settingsLoginSubSignIn =>
      'Sign in to see your rides and notifications.';

  @override
  String get settingsLoginSavedHost => 'Saved server';

  @override
  String get settingsLoginServer => 'Server address';

  @override
  String get settingsLoginUsername => 'Username';

  @override
  String get settingsLoginPassword => 'Password';

  @override
  String get settingsLoginHaveAccount => 'I already have an account';

  @override
  String get settingsLoginAdvanced => 'Advanced: connect with a device token';

  @override
  String get settingsLoginConnect => 'Connect';

  @override
  String get settingsLoginSkip => 'Skip for now';

  @override
  String get settingsLoginEnterUrl => 'Enter the server address.';

  @override
  String get settingsLoginInsecureUrl =>
      'Insecure address: use https:// or a server on the local network.';

  @override
  String get settingsLoginNeedCredentials =>
      'Username and password are required.';

  @override
  String get settingsLoginNeedVehicle =>
      'Vehicle ID and claim code are required.';

  @override
  String get settingsLoginNeedToken => 'Enter the device token.';

  @override
  String get settingsLoginSessionEnded =>
      'Session ended. Please sign in again.';
}
