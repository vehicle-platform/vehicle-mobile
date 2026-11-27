# vehicle-mobile

The companion app for the `vehicle-platform` motorcycle telemetry, diagnostics, and rider-assistant stack (Flutter, D-022). It runs on Android/iOS phones and as a web or macOS client (D-121). It connects to the motorcycle over BLE via `vehicle-connectivity-node` (phone only) and talks to `vehicle-server` over HTTPS/HTTP for ride history, ride event marks, notifications, in-ride alerts, and the rider assistant.

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
  - **Signals (`lib/ui/signals_screen.dart`):** every signal in the generated `vehicleSignalCatalog` (D-066) grouped with `LIVE` (valid sample received within 2000 ms), `STALE`, `SKIPPED`, `NRC 0x31`, `NO DATA`, or `NOT POLLED` chips, age, and poll period.
  - **Record (`lib/ui/record_screen.dart`):** local ride recording, session metadata, live packet counters, share, and optional upload to `vehicle-server`.
  - **Diagnostics (`lib/ui/diagnostics_screen.dart`):** BLE link health, packet loss, vehicle CAN counters, and D-058 tester statistics.
- **Garage (`lib/ui/garage/garage_screen.dart`):** two-way segmented view of the **Notification Inbox** (`lib/ui/notifications/notifications_screen.dart`, grouped by day with severity accents and an "Ask Assistant" action) and the **Fault Catalog** (`lib/ui/faults/faults_screen.dart`, read-only displayable entries from `GET /faults`). Wide windows show master-detail for notifications.
- **Logbook (`lib/ui/rides/ride_history_screen.dart`, `ride_summary_screen.dart`):** server ride history (`GET /rides`) with date filtering, per-ride summary (`GET /sessions/{id}/summary`: scalars, binned charts, D-079 health windows in `health_windows_section.dart`), **Ride marks** (`ride_marks_section.dart`), and **Bring-up check** (`bringup_screen.dart`, `GET /sessions/{id}/bringup?gate=B0|V0|V1`).
- **Assistant (`lib/ui/assistant/assistant_screen.dart`):** logbook-style chat transcript against `POST /chat` with stored conversations (`conversations_controller.dart`, `conversation_list.dart`, `/conversations*`), temporary chat toggle, answering model chip (`model_chip.dart`, D-127), expandable data cards labelled with the tool that computed them, follow-up chips (D-128), and a large hold-to-talk control on phones.
- **Settings (`lib/ui/settings_screen.dart`):** account management and vehicle claiming (D-122), language selector (`LocaleController`, D-125), host list (`lib/services/host_store.dart`, `host_resolver.dart`, D-121 item 4), Wi-Fi-only upload toggle, voice read-aloud toggle, per-rule alert mutes (`lib/ui/settings/alert_types_section.dart`, D-129), assistant provider configuration (`lib/ui/settings/assistant_model_screen.dart`, D-124), and user-visible assistant memory (`lib/ui/settings/assistant_memory_screen.dart`, D-128).
- **Login (`lib/ui/auth/auth_gate.dart`, `login_screen.dart`):** shown when the active host has no token (skippable on the phone because BLE and local recording work offline); supports account login, registration with vehicle ID + claim code, and manual device-token entry.

## Ride event marks and offline queue (D-133)

Riders can tag timestamped, position-free events (`{id, t_utc, kind, note?}`, no GPS fields per D-076) during a ride as consented weak labels:

- **Live picker (`lib/ui/widgets/mark_picker.dart`, `lib/models/ride_mark.dart`):** large (>= 64 px) **Mark event** button on `LiveScreen` opens an auto-closing (5 s) quick picker. Kinds (`RideMarkKind`): `misfire`, `noise`, `vibration`, `warning_light`, `rough_road`, `traffic`, `other`.
- **Offline queue (`lib/services/mark_queue.dart`):** marks are assigned a client ID (`m_<utc_ms>_<hex>`), persisted in `SharedPreferences` (`ride_mark_queue_v1`), and deduplicated by `id` across backgrounding and app restarts. Every read-modify-write runs under one serialized async lock (`_locked`). Pending marks retry with exponential backoff (5 s doubling up to 5 min; timer cancelled on `dispose`). Permanent server rejections (`422` / `409`) drop the mark and increment `rejectedCount` so the UI informs the rider.
- **HTTP client (`lib/services/marks_client.dart`):** calls `POST /marks` (idempotent 201/200), `GET /rides/{ride_id}/marks`, and `DELETE /marks/{mark_id}` (treating 404 as already deleted).
- **Logbook view (`lib/ui/rides/ride_marks_section.dart`):** `RideSummaryScreen` lists marks matched to that ride's UTC window with per-mark delete and error feedback.

## In-ride alerts, notifications, and voice (D-121, D-123, D-129)

- **In-ride alerts (`lib/services/alerts/`):** `AlertController` subscribes to `GET /alerts/stream?locale=<en|tr>` (SSE via `alert_opener_io.dart` on native or `fetch` `ReadableStream` in `alert_opener_web.dart`, parsed by `sse.dart`) with exponential reconnect backoff (1, 2, 4, 8, 15, 30 s) and pulls `GET /notifications` on reconnect because SSE does not replay. `AlertBanner` (`lib/ui/widgets/alert_banner.dart`) shows P1 urgent alerts (red stripe, max 30 s display) and P2 advisory alerts (amber stripe, max 12 s display), clearing early on a `clear` event. Per-rule mutes are persisted in `AlertPrefs`: P1 mutes voice only (banner always displays); P2 mutes banner and voice while keeping the inbox record. P0 safety outputs stay exclusively on `vehicle-safety-node`.
- **Notifications (`lib/services/notifications/`):** `NotificationCenter` polls `GET /notifications?since_id=&limit=&locale=` every 60 s in foreground and on resume, tracks unread counts and `NotificationStore` cursors per host, and marks items read via `POST /notifications/{id}/read` and `read-all`. Android also runs a 15-minute `workmanager` background pull showing local notifications via `flutter_local_notifications`. A `404` hides the feature quietly on older servers.
- **Voice and Bluetooth intercom (`lib/services/voice/`):** `VoiceController` coordinates on-device speech recognition (`speech_to_text`, BSD-3-Clause; 10 s start timeout) and TTS (`flutter_tts`, MIT), following the active UI locale (`en-US` default, `tr-TR` when Turkish is selected).
  - **Android HFP intercom (`intercom_audio.dart`, `IntercomAudio.kt`):** routes audio over HFP (`AudioManager.setCommunicationDevice` on API 31+, `startBluetoothSco` on older APIs) and speaks via framework `TextToSpeech` with `USAGE_VOICE_COMMUNICATION`, releasing the route after each turn (an active HFP session pauses intercom group talk like a phone call). Falls back to phone mic/speaker without a headset.
  - **Triggers (`voice_triggers.dart`, `lib/models/rider_input.dart`):** supports Android `android.intent.action.VOICE_COMMAND` (intercom assistant button) and the handlebar push-to-talk BLE characteristic (`riderInput`, `RiderInputTracker` using generated `BleRiderInput*` constants: hold-to-talk sends transcript on release; empty tap repeats last answer; empty long hold does nothing).
  - **Critical announcer (`critical_announcer.dart`):** speaks P1 alerts and `advise_stop: true` warnings offline from localized fixed templates without waiting for `/chat`. Voice is informational only.

## Internationalization (D-125, D-130)

User-facing text defaults to **English (`en`)** with **Turkish (`tr`)** as the second locale (`lib/l10n/`):

- **Source files:** modular JSON parts live in `l10n_src/parts/*.{en,tr}.json`.
- **Merging and code generation:** `python3 tool/l10n_merge.py` builds `lib/l10n/app_en.arb` and `lib/l10n/app_tr.arb` (`test/i18n_test.dart` verifies the merged ARB files stay in sync with `l10n_src/`), and `flutter gen-l10n` (configured by `l10n.yaml`) generates `lib/l10n/app_localizations*.dart`.
- **Runtime switching & formatting:** `LocaleController` (`lib/l10n/locale_controller.dart`) persists the user's locale choice (`null` = system fallback to `en`), `rider_format.dart` formats numbers and dates per locale, and server requests pass the active `locale` (`en` or `tr`).

## Accounts and hosts (D-121, D-122)

- **Accounts (`lib/services/auth_client.dart`, `auth_store.dart`, `auth_events.dart`):** supports `POST /auth/login`, `POST /auth/register`, `POST /auth/logout`, `GET /auth/me`, and `POST /vehicles/claim`. Session tokens are stored per host in `flutter_secure_storage` (`host.<id>.token`); username and vehicle list live in `SharedPreferences`. Any `401` clears that host's session and returns to login. Tokens and passwords are never logged.
- **Hosts (`lib/services/host_store.dart`, `host_resolver.dart`):** per-user ordered host list (e.g., local Raspberry Pi first, remote server second); `HostResolver` probes `GET /health` (2 s timeout) in list order and caches the active host. On web, an empty host list defaults to the page's origin.

## BLE telemetry schema and ride recording (D-058, D-061)

BLE notification formats (`lib/models/telemetry_data.dart` v2/v3/v4, `imu_block.dart`, `gps_block.dart`, `vehicle_signal_block.dart`, `rider_input.dart`), GATT UUIDs, and MTU come solely from the generated `vehicle_defs` Dart package in `external/vehicle-defs/gen/dart/vehicle_defs` (pinned to a release tag).

Recording writes `meta.json`, `telemetry.csv`, `events.csv`, `summary.json`, and optional `imu.csv`, `gps.csv` (speed and heading only, D-060; requires BLE bond per D-062), and `signals.csv` to `<app documents>/sessions/<session_id>/` per `docs/session-format.md`.

### Security notes and known limitations

- **Cleartext HTTP (`lib/services/token_guard.dart`):** bearer tokens and ride data may use `http://` only for loopback, RFC 1918 / ULA private networks, link-local, or `.local` hosts; all other hosts require `https://`.
- **Backups:** Android `allowBackup` is disabled and data-extraction rules exclude all app data (sessions may contain GPS tracks, D-063).
- **APK signing:** the CI release APK (`vehicle-mobile-apk-debug-signed`) uses the Android debug key (workshop/testing only).
- **BLE peer selection:** connects to the first advertiser whose name contains `Honda-CL250`; only the GPS characteristic enforces bonding (D-062).

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

## License

MIT, see `LICENSE` (D-036).
