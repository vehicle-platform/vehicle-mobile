# vehicle-mobile

The companion app for the `vehicle-platform` motorcycle telemetry, diagnostics, and rider-assistant stack (Flutter, D-022). It runs on Android/iOS phones and as a web or macOS client (D-121); the computer client has no BLE destinations. It connects to the motorcycle over BLE via `vehicle-connectivity-node` (phone only) and talks to `vehicle-server` over HTTPS/HTTP for ride history, ride event marks, notifications, in-ride alerts, and the rider assistant.

The app is strictly non-safety-critical (platform invariant 3): the motorcycle and safety MCU operate fully whether or not the phone is connected.

## Origin

Ported from `HondaCl250_Telemetry@legacy-final` (`mobile_app/flutter_app`) per D-023. The BLE client, packet decoders, and dashboard were carried over and updated to decode BLE telemetry packet versions 2, 3, and 4 (D-058) strictly from the generated `vehicle_defs` Dart package (D-061).

## Screens and navigation (D-130)

High-contrast dark Material 3 design (`lib/ui/theme/app_theme.dart`, bundled Instrument Sans and Barlow Semi Condensed fonts in `lib/ui/theme/typography.dart`, spacing scale 4/8/12/16/24/32 in `lib/ui/theme/spacing.dart`). Layout adapts by window width (`lib/ui/theme/layout.dart`):

- **< 600 px (phone / narrow):** bottom navigation bar, full-width content, 16 px gutters; Settings is opened from the header.
- **600–900 px:** left navigation rail with single panes and Settings in the rail.
- **>= 900 px (web / desktop):** left navigation rail, list + detail panes (`lib/ui/shell/master_detail.dart`), Assistant as a side panel, and a `Ctrl/Cmd+K` command bar (`lib/ui/shell/command_bar.dart`).

Top-level destinations (`lib/ui/app_shell.dart`):

- **Ride (phone only, `lib/ui/shell/ride_destination.dart`):** slim sub-navigation across four tabs (`Live`, `Signals`, `Record`, `Diagnostics`); `Record` keeps its state mounted while an active recording runs.
  - **Live (`lib/ui/live_screen.dart`):** hero speed, RPM, and throttle readouts, secondary coolant/battery tiles, link status strip (BLE, ECU, CAN state, latches, mock data, IMU, GPS), and the glove-friendly **Mark event** button.
  - **Signals (`lib/ui/signals_screen.dart`):** every signal in the generated `vehicleSignalCatalog` (D-066) grouped with `LIVE` (valid sample received within 2000 ms), `STALE`, `SKIPPED`, `NRC 0x31`, `NO DATA`, or `NOT POLLED` chips, age, and poll period. Catalog candidates stay `NOT POLLED` until the node reports them; once promoted in firmware they turn `LIVE` with no code change. `lib/ui/telemetry/signal_view.dart` maps polled catalog signals to decoded telemetry fields by generated `VehicleSignalNames`; `test/signal_view_test.dart` covers the bindings.
  - **Record (`lib/ui/record_screen.dart`):** local ride recording, session metadata, live packet counters, sessions list, share, and optional upload to `vehicle-server` (see "BLE telemetry schema and ride recording"). The app-bar **Server rides** action opens the Logbook; an uploaded session also offers **Ride summary** and **Bring-up check** actions.
  - **Diagnostics (`lib/ui/diagnostics_screen.dart`):** BLE link health, packet loss, vehicle CAN counters, and D-058 tester statistics.
- **Garage (`lib/ui/garage/garage_screen.dart`):** two-way segmented view of the **Notification Inbox** (`lib/ui/notifications/notifications_screen.dart`, grouped by day with severity accents and an "Ask Assistant" action) and the **Fault Catalog** (`lib/ui/faults/faults_screen.dart`, read-only displayable entries from `GET /faults`). Wide windows show master-detail for notifications.
- **Logbook (`lib/ui/rides/ride_history_screen.dart`, `ride_summary_screen.dart`):** server ride history (`GET /rides`) (read-only, newest first, date-range filter, up to two chosen columns) with date filtering, per-ride summary (`GET /sessions/{id}/summary`: scalars, binned charts, not-available signals, D-079 health windows in `health_windows_section.dart`), **Ride marks** (`ride_marks_section.dart`), and **Bring-up check** (`bringup_screen.dart`, `GET /sessions/{id}/bringup?gate=B0|V0|V1`, default V0; also reachable from the Record screen's session actions and the ride summary's app bar). It renders only the server's `verdict`, `checks`, `needs_you` and `warnings` and computes nothing itself. Gates: B0 bench (report status, IMU gaps, at-rest check), V0 vehicle (ECU present, every polled DID valid, no latch or bus-off), V1 (V0 CAN health over at least 5 min plus the manual throttle blip); exact criteria in `external/vehicle-defs/docs/hardware-integration.md` §6. Needs a `vehicle-server` with the bring-up route (server#50). Nothing in the Logbook writes, recomputes or deletes on the server (except ride marks).
- **Assistant (`lib/ui/assistant/assistant_screen.dart`):** logbook-style chat transcript against `POST /chat` with stored conversations (`conversations_controller.dart`, `conversation_list.dart`, `/conversations*`), temporary chat toggle, answering model chip (`model_chip.dart`, D-127), expandable data cards labelled with the tool that computed them, follow-up chips (D-128), and a large hold-to-talk control on phones.
- **Settings (`lib/ui/settings_screen.dart`):** account management and vehicle claiming (D-122), language selector (`LocaleController`, D-125), host list (`lib/services/host_store.dart`, `host_resolver.dart`, D-121 item 4), Wi-Fi-only upload toggle, voice read-aloud toggle, per-rule alert mutes (`lib/ui/settings/alert_types_section.dart`, D-129), assistant provider configuration (`lib/ui/settings/assistant_model_screen.dart`, D-124), and user-visible assistant memory (`lib/ui/settings/assistant_memory_screen.dart`, D-128).
- **Login (`lib/ui/auth/auth_gate.dart`, `login_screen.dart`):** shown when the active host has no token (skippable on the phone because BLE and local recording work offline); supports account login, registration with vehicle ID + claim code, and manual device-token entry.

### Display modes

Settings > Display: System (dark first), Dark, Light, Sunlight (`lib/ui/theme/theme_controller.dart`, saved as `ui_theme`). Sunlight is the light theme for direct daylight: white surfaces, black text, every text and state colour at WCAG AAA (>= 7:1) on every surface, borders >= 4.5:1 and 2 px wide (`VehicleTokens.sunlight`, checked by `test/theme_contrast_test.dart`). The ride screen has a one-tap sun button that switches sunlight on and back to the previous choice.

## Ride event marks and offline queue (D-133)

Riders can tag timestamped, position-free events (`{id, t_utc, kind, note?}`, no GPS fields per D-076) during a ride as consented weak labels:

- **Live picker (`lib/ui/widgets/mark_picker.dart`, `lib/models/ride_mark.dart`):** large (>= 64 px) **Mark event** button on `LiveScreen` opens an auto-closing (5 s) quick picker. Kinds (`RideMarkKind`): `misfire`, `noise`, `vibration`, `warning_light`, `rough_road`, `traffic`, `other`.
- **Offline queue (`lib/services/mark_queue.dart`):** marks are assigned a client ID (`m_<utc_ms>_<hex>`), persisted in `SharedPreferences` (`ride_mark_queue_v1`), and deduplicated by `id` across backgrounding and app restarts. Every read-modify-write runs under one serialized async lock (`_locked`). Pending marks retry with exponential backoff (5 s doubling up to 5 min; timer cancelled on `dispose`). Permanent server rejections (`422` / `409`) drop the mark and increment `rejectedCount` so the UI informs the rider.
- **HTTP client (`lib/services/marks_client.dart`):** calls `POST /marks` (idempotent 201/200), `GET /rides/{ride_id}/marks`, and `DELETE /marks/{mark_id}` (treating 404 as already deleted).
- **Logbook view (`lib/ui/rides/ride_marks_section.dart`):** `RideSummaryScreen` lists marks matched to that ride's UTC window with per-mark delete and error feedback.

## In-ride alerts, notifications, and voice (D-121, D-123, D-129)

- **In-ride alerts (`lib/services/alerts/`):** `AlertController` subscribes to `GET /alerts/stream?locale=<en|tr>` (SSE via `alert_opener_io.dart` on native or `fetch` `ReadableStream` in `alert_opener_web.dart`, parsed by `sse.dart`) with exponential reconnect backoff (1, 2, 4, 8, 15, 30 s) and pulls `GET /notifications` on reconnect because SSE does not replay. `AlertBanner` (`lib/ui/widgets/alert_banner.dart`) shows P1 urgent alerts (red stripe, max 30 s display) and P2 advisory alerts (amber stripe, max 12 s display), clearing early on a `clear` event. Per-rule mutes are persisted in `AlertPrefs`: P1 mutes voice only (banner always displays); P2 mutes banner and voice while keeping the inbox record. P0 safety outputs stay exclusively on `vehicle-safety-node`.
- **Notifications (`lib/services/notifications/`):** `NotificationCenter` polls `GET /notifications?since_id=&limit=&locale=` every 60 s in foreground and on resume, tracks unread counts and `NotificationStore` cursors per host, and marks items read via `POST /notifications/{id}/read` and `read-all`. Android also runs a 15-minute `workmanager` background pull showing local notifications via `flutter_local_notifications`. A `404` hides the feature quietly on older servers. Fresh unread critical entries go to `CriticalAnnouncer` as `HighSeverityFaultEvent` (spoken once per id when voice is on). Android uses the channels "Vehicle notifications" and "Critical vehicle notifications" (high importance) and asks for `POST_NOTIFICATIONS` (Android 13+) on shell start; web and desktop stay in-app. Plugin licences: `flutter_local_notifications` BSD-3-Clause, `workmanager` MIT.
- **Voice and Bluetooth intercom (`lib/services/voice/`):** `VoiceController` coordinates on-device speech recognition (`speech_to_text`, BSD-3-Clause; microphone permission requested first, recogniser start bounded to 10 s, then "Speech recognition is not available") and TTS (`flutter_tts`, MIT), following the active UI locale (`en-US` default, `tr-TR` when Turkish is selected). The composer mic shows the live transcript; the final transcript goes down the normal `POST /chat` path and the answer text (never the tool card) is read aloud when the Settings read-aloud toggle is on (default on for phones, off for web and desktop). Tapping the mic again or sending a new question stops speech.
  - **Android HFP intercom (`intercom_audio.dart`, `IntercomAudio.kt`):** routes audio over HFP (`AudioManager.setCommunicationDevice` on API 31+, `startBluetoothSco` on older APIs) and speaks via framework `TextToSpeech` with `USAGE_VOICE_COMMUNICATION`, releasing the route after each turn (an active HFP session pauses intercom group talk like a phone call, for as long as the route is held). API 31+ uses `MODE_IN_COMMUNICATION`; older APIs wait up to 3 s for `SCO_AUDIO_STATE_CONNECTED`. Method channel `vehicle_mobile/intercom_audio` (framework APIs only; `flutter_tts` cannot set `USAGE_VOICE_COMMUNICATION`, so it is used only without a headset). Falls back to phone mic/speaker without a headset or when `BLUETOOTH_CONNECT` (Android 12+) is denied; the Assistant shows a chip ("Intercom connected" / "Phone microphone").
  - **Intercom voice button:** the main activity answers `android.intent.action.VOICE_COMMAND`; select this app under Android default digital assistant / voice input, then the headset's voice-command button opens the Assistant and starts listening (cold start and running app).
  - **Triggers (`voice_triggers.dart`, `lib/models/rider_input.dart`):** supports Android `android.intent.action.VOICE_COMMAND` (intercom assistant button) and the handlebar push-to-talk BLE characteristic (`riderInput`, `RiderInputTracker` using generated `BleRiderInput*` constants: hold-to-talk sends transcript on release; empty tap repeats last answer; empty long hold does nothing). The tracker drops a block with the same `seq` as the previous one, counts lost blocks as `(seq - prev - 1) mod 256`, resynchronises from `flags.buttonDown`, and ignores a press older than 2 s against the latest `deviceTimeMs`; the firmware's `longPress` block only marks the hold as long. The subscription is skipped on firmware without the characteristic.
  - **Critical announcer (`critical_announcer.dart`):** speaks P1 alerts, `advise_stop: true` chat results ("Stop in a safe place and have the engine checked." after the answer) and fresh critical notifications offline from localized fixed templates, never through `/chat`. Voice is informational only.

## Internationalization (D-125, D-130)

User-facing text defaults to **English (`en`)** with **Turkish (`tr`)** as the second locale (`lib/l10n/`):

- **Source files:** modular JSON parts live in `l10n_src/parts/*.{en,tr}.json`.
- **Merging and code generation:** `python3 tool/l10n_merge.py` builds `lib/l10n/app_en.arb` and `lib/l10n/app_tr.arb` (`test/i18n_test.dart` verifies the merged ARB files stay in sync with `l10n_src/`), and `flutter gen-l10n` (configured by `l10n.yaml`) generates `lib/l10n/app_localizations*.dart`.
- **Runtime switching & formatting:** `LocaleController` (`lib/l10n/locale_controller.dart`) persists the user's locale choice (`null` = system fallback to `en`), `rider_format.dart` formats numbers and dates per locale, and server requests pass the active `locale` (`en` or `tr`).

## Accounts and hosts (D-121, D-122)

- **Accounts (`lib/services/auth_client.dart`, `auth_store.dart`, `auth_events.dart`):** supports `POST /auth/login`, `POST /auth/register`, `POST /auth/logout`, `GET /auth/me`, and `POST /vehicles/claim`. Session tokens are stored per host in `flutter_secure_storage` (`host.<id>.token`); username and vehicle list live in `SharedPreferences`. Any `401` clears that host's session and returns to login. Tokens and passwords are never logged.
- **Hosts (`lib/services/host_store.dart`, `host_resolver.dart`):** per-user ordered host list (e.g., local Raspberry Pi first, remote server second); `HostResolver` probes `GET /health` (2 s timeout) in list order and caches the active host. On web, an empty host list defaults to the page's origin. Tokens live in `flutter_secure_storage`, never in prefs, never logged. The first start migrates the old single URL/token (`settings.server_base_url`, `settings.api_token`) into the first host (`primary`). The choice is cached until a pull-to-refresh or a failed request probes again; each host keeps the token guard rules.

## BLE telemetry schema and ride recording (D-058, D-061)

BLE notification formats (`lib/models/telemetry_data.dart` v2/v3/v4, `imu_block.dart`, `gps_block.dart`, `vehicle_signal_block.dart`, `rider_input.dart`), GATT UUIDs, and MTU come solely from the generated `vehicle_defs` Dart package in `external/vehicle-defs/gen/dart/vehicle_defs` (pinned to a release tag).

Recording writes `meta.json`, `telemetry.csv`, `events.csv`, `summary.json`, and optional `imu.csv`, `gps.csv` (speed and heading only, D-060; requires BLE bond per D-062), and `signals.csv` to `<app documents>/sessions/<session_id>/` per `docs/session-format.md` (the contract shared with `vehicle-server`). Sessions can be shared locally at any time; upload (`POST /sessions` via `lib/services/upload_client.dart`, `session_upload.dart`; Wi-Fi-only by default) is a separate optional action and never blocks recording or sharing. The GPS characteristic needs the phone bonded with the bike (D-062): on Android the app starts pairing on connect (`createBond`); telemetry, IMU, vehicle-signal and `riderInput` characteristics work without it, and firmware without a characteristic is simply not subscribed to. `signals.csv` holds engine data only, so the D-063 local-only rule applies to `gps.csv` alone. The tests build packets byte by byte from the generated offsets; a layout change is a defs change plus a version bump, never a hand edit here. After cloning, run `git submodule update --init` first.

### Security notes and known limitations

- **Cleartext HTTP (C-2, `lib/services/token_guard.dart`):** the manifest permits cleartext because Android's network security config cannot express IP ranges and the desk setup talks to a laptop by LAN IP. The restriction is in Dart: bearer tokens and ride data may use `http://` only for loopback, RFC 1918 / ULA private networks, link-local, or `.local` hosts; all other hosts require `https://`. User-installed CAs are not trusted.
- **Backups:** Android `allowBackup` is disabled and data-extraction rules exclude all app data (sessions may contain GPS tracks, D-063) (C-3).
- **APK signing:** the CI release APK (`vehicle-mobile-apk-debug-signed`) uses the Android debug key: workshop installs only. A real release keystore (CI secrets, never committed) is required before any distribution, and installs cannot be updated across a signing-key change (C-3).
- **BLE peer selection:** connects to the first advertiser whose name contains `Honda-CL250`; telemetry and IMU characteristics need no bond, so a nearby device with that name could feed fake data into a recorded ride; only the GPS characteristic enforces bonding (D-062). Not a safety issue (the phone is not safety-relevant); pinning the bonded device id or filtering by service UUID is a follow-up (C-10).
- **Telematics write (C-11):** `|` and line breaks are replaced by a space in song/artist text (`BleService._telematicsText`) because the receiver has no escape for them; the BLE schema is unchanged.

## Build and test

```bash
git submodule update --init          # external/vehicle-defs (pinned release tag)
flutter pub get
python3 tool/l10n_merge.py           # merge l10n_src/parts into lib/l10n/app_{en,tr}.arb
flutter gen-l10n                     # regenerate lib/l10n/app_localizations*.dart
flutter analyze
flutter test
flutter build web --release --base-href /app/   # computer client served by vehicle-server at /app
flutter build apk --release                     # Android APK (debug-signed in CI)
```

Web and macOS: `flutter build macos` for the desktop client. `vehicle-server` serves the web build without auth at `/app` on the same origin: point `VEHICLE_WEB_APP_DIR` at `build/web`. BLE telemetry, signals, recording and diagnostics are phone-only (Android/iOS) and compiled out of the web build (`lib/ui/phone/phone_tabs_stub.dart`). The macOS sandbox has `com.apple.security.network.client` plus the audio-input entitlement for voice. Speech recognition and read-aloud work on Android, web (browser speech APIs) and macOS.

## License

MIT, see `LICENSE` (D-036).
