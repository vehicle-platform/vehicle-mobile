# vehicle-mobile

The phone companion app for the vehicle-platform motorcycle telemetry/diagnostics
system (see the workspace `CLAUDE.md` / `PLATFORM-RULES.md` for the full
platform picture). Written in Flutter (D-022). Scope: settings, ride
history/reports, park-mode alarm notifications, and profile selection. It
talks to the vehicle over BLE/Wi-Fi via `vehicle-connectivity-node`, and to the
`vehicle-server` API for historical data. The app is not involved in anything
safety-critical: the vehicle works fully whether or not the phone is
connected.

## Origin

Ported from `HondaCl250_Telemetry@legacy-final` (`mobile_app/flutter_app`)
per decision D-023. The web PWA and the complementary-filter lean angle
estimate were dropped; the BLE client, packet decoder and dashboard were
carried over and updated for the BLE telemetry packet schema (now version 4,
D-058, with version 3 still decoded and version 2 kept as the low-MTU
fallback).

## App screens

Dark, high-contrast Material 3 theme; every color and text style lives in
`lib/ui/theme/app_theme.dart`. Six destinations on the phone (`lib/ui/app_shell.dart`);
the computer (web, macOS) shows only Assistant, Rides, Faults and Settings (D-121).
The layout follows the window WIDTH, not the platform: below 600 px a bottom
navigation bar with full-width content and 16 px gutters (also a phone browser or
a narrow window), 600-1024 px a navigation rail, above 1024 px the rail plus a
centred content column (720 px Assistant, 960 px lists and forms). Spacing is the
4/8/12/16/24/32 scale (`Spacing`), width classes and the column helper live in
`lib/ui/theme/layout.dart`:

- **Live:** speed, RPM, throttle, coolant and battery with their state, and a
  status strip (BLE, ECU, CAN state, latches, mock data, IMU, GPS).
- **Signals:** every signal of the defs catalog (D-066,
  `vehicleSignalCatalog`), grouped, with a LIVE / STALE / SKIPPED / `NRC 0x31` /
  NO DATA / NOT POLLED chip, age and poll period. The latest vehicle-signal
  record per DID drives it: a signal is LIVE when its record is valid and the
  phone received it within 2000 ms (the five telemetry-v4 signals keep their
  100 ms v4 values while those say LIVE). Candidates stay NOT POLLED until the
  node reports them; once a candidate is promoted in the firmware it turns LIVE
  with no code change. This screen is how the bike shows which signals flow.
- **Record:** session metadata, live counters, sessions and upload (unchanged
  behaviour, D-063 still applies).
- **Diagnostics:** link, packet loss, vehicle CAN counters and the D-058 tester
  statistics.
- **Assistant "Sürüş Asistanı" (D-121):** text chat against `POST /chat` of the active host. The
  server picks one read-only vehicle-mcp tool and phrases its result; each answer
  shows a source badge ("Asistan" / "Veriden doğrulandı") and an expandable "computed by `<tool>`"
  card with the tool arguments and result as key/value rows. The app never
  computes or rephrases a number and adds no advice. The conversation is kept in
  memory only. Opened from a ride summary it sends that ride's `session_id`.
  **Voice (D-121 items 5 and 7, D-047, D-085 item 4):** the mic button in the
  composer listens (tr-TR, device default as fallback; teal pulsing ring and the
  live transcript in the input); the final transcript goes down the normal
  `POST /chat` path and the answer text (never the tool card) is read aloud when
  Settings > "Cevapları sesli oku" is on (default on for the phone, off for web
  and desktop). Tapping the mic again or sending a new question stops the
  speech. Voice is informational only and never a safety output.
- **Rides / Faults (computer tabs):** the server's ride history and fault
  catalogue (also reachable on the phone through Record and the ride screens).
- **Notifications (D-123):** a bell with an unread badge in the app bar of the
  Assistant, Rides, Faults and Settings screens opens the inbox (grouped by day,
  severity accent: critical red, warning amber, info teal). A tap opens the detail
  with a link to the ride and "Sürüş Asistanı'na sor" (opens the assistant with a
  prefilled question and the ride's `session_id`); "Tümünü okundu say" marks all.
- **Login (D-122):** when the active host has no token the app shows a login
  screen (server address - prefilled with the page origin on the web -, username,
  password); "Hesap oluştur" registers with a vehicle ID and claim code; "Gelişmiş"
  keeps the manual device-token path. On the phone the login can be skipped
  (BLE and recording need no server).
- **Settings:** the account (user, vehicles, "Araç ekle", "Çıkış yap"), the host
  list (below) and the Wi-Fi-only upload switch.

## Accounts (D-122)

`lib/services/auth_client.dart` talks to vehicle-server: `POST /auth/login`,
`POST /auth/register`, `POST /auth/logout`, `GET /auth/me`, `POST /vehicles/claim`.
The session token goes to the keystore under the host's `host.<id>.token` key; the
username and vehicle list are in shared_preferences (`auth.<id>.account`). A 401
from any client (`AuthEvents`) clears that host's session and returns to the login
screen with a short message. Tokens and passwords are never logged; password
fields are obscured with autocorrect off.

## Notifications (D-123)

`lib/services/notifications/`: `notifications_client.dart` (`GET /notifications?since_id=&limit=`,
`POST /notifications/{id}/read`, `POST /notifications/read-all`), `NotificationStore`
(last seen id per host, in prefs), `NotificationSync` (one pull, pages through the
answer, only ids above the stored one are "fresh"), and `NotificationCenter`
(inbox state, unread badge, 60 s foreground poll, pull on resume and pull-to-refresh).
A 404 (older server) hides the bell. Critical fresh entries go to the
`CriticalAnnouncer` as `HighSeverityFaultEvent` (spoken once per id when voice is on;
D-121 item 7b). Android only: a `workmanager` periodic task (every 15 minutes)
pulls while the app is closed and shows local notifications through
`flutter_local_notifications` on the channel "Araç bildirimleri" (critical ones on a
high-importance channel); Android 13+ asks for the POST_NOTIFICATIONS permission
at the first start of the shell. Web and desktop stay in-app. Plugin licences:
flutter_local_notifications BSD-3-Clause, workmanager MIT.

## Hosts (D-121 item 4)

Settings keeps a per-user list of hosts (`name`, `baseUrl`), for example the local
Raspi and a remote server. The list is in shared_preferences; each host's device
token is in flutter_secure_storage under `host.<id>.token` (never in prefs, never
logged). The first start migrates the old single URL/token into the first host.
Every server client uses the *active host*: hosts are probed in list order with
`GET /health` (2 s), the first that answers wins, and the choice is cached until
a pull-to-refresh or a failed request probes again. Each host keeps the token
guard rules (https, or http only on the local network).

## Web and macOS builds

```
flutter build web --release --base-href /app/
flutter build macos
```

vehicle-server serves the web build at `/app` on the same origin: point
`VEHICLE_WEB_APP_DIR` at `build/web`. On web, an empty host list defaults to the
page's own origin. BLE telemetry, signals, recording and diagnostics are
phone-only (Android/iOS) and not compiled into the web build; the macOS sandbox
has `com.apple.security.network.client` plus the microphone entitlement for
voice. Speech recognition and reading aloud work on Android, web (browser
speech APIs, Chrome) and macOS.

## Voice, intercom and handlebar push-to-talk (D-121 items 5 and 7)

- **Plugins:** `speech_to_text` (BSD-3-Clause) and `flutter_tts` (MIT).
- **Intercom routing (Android only).** The rider's Bluetooth intercom is an HFP
  headset. Before listening and while speaking, `IntercomAudio` (Kotlin method
  channel `vehicle_mobile/intercom_audio`, framework APIs only) routes the audio
  to it: API 31+ `AudioManager.setCommunicationDevice` with
  `MODE_IN_COMMUNICATION`; older `startBluetoothSco()` and a 3 s wait for
  `SCO_AUDIO_STATE_CONNECTED`. It is released after each step and the audio mode
  restored. Speech while routed uses the framework `TextToSpeech` with
  `USAGE_VOICE_COMMUNICATION` (flutter_tts cannot set those attributes; without
  a headset flutter_tts is used). With no headset the phone microphone and
  speaker are used. A small chip in Sürüş Asistanı shows "İntercom bağlı" or "Telefon
  mikrofonu". **An HFP session pauses the intercom's group talk, like a call
  does**, for as long as the route is held. Android 12+ asks for
  BLUETOOTH_CONNECT (denied: the phone is used).
- **Intercom voice button.** The main activity answers
  `android.intent.action.VOICE_COMMAND`. In Android Settings > Apps > Default
  apps > Digital assistant / voice input (or the chooser the first time the
  headset's voice-command button is pressed) select this app. Pressing the
  button then opens Sürüş Asistanı and starts listening; a cold start and a running app
  are both handled.
- **Handlebar push-to-talk (phone only).** The app subscribes to the
  `riderInput` characteristic when the firmware offers it (older firmware:
  ignored). Decoding and de-duplication are in `lib/models/rider_input.dart`
  (`RiderInputTracker`) and use only the generated `BleRiderInput*` constants:
  same seq as the previous block is dropped, lost blocks are counted
  (`(seq - prev - 1) mod 256`), `flags.buttonDown` resynchronises, and a press
  older than 2 s (against the latest `deviceTimeMs` of the other blocks) is
  ignored. Hold-to-talk works for any hold length: press starts listening (a
  press while Sürüş Asistanı speaks stops the speech first); the firmware's `longPress`
  block during the hold is ignored (it only marks the hold as long); release
  stops listening and sends the transcript. An empty transcript after a long
  hold does nothing; an empty transcript after a tap (release with no
  `longPress` before it) repeats the last answer by voice, if there is one.
- **Speech start bound.** The microphone permission is requested first (Android),
  then the recogniser start is bounded to 10 s; on timeout the mic goes back to
  idle with "Ses tanıma kullanılamıyor".
- **Critical warnings without the LLM.** `CriticalAnnouncer` speaks fixed Turkish
  templates offline, never through `/chat`: when a chat answer's tool result has
  `advise_stop: true` the app speaks "Güvenli bir yerde dur ve motoru kontrol
  ettir." after the answer. `announce(HighSeverityFaultEvent)` (once per fault id,
  with the server's own title) is ready, but the app has no live fault feed yet
  (`GET /faults` is the static catalogue, `/ws/live` carries CAN frames), so
  nothing calls it today. Informational only (invariant 3).

`lib/ui/telemetry/signal_view.dart` maps the polled catalog signals to the
decoded telemetry fields, keyed by the generated `VehicleSignalNames`; a test
fails if a polled DID has no binding. The Nextion telematics form of the legacy
dashboard is gone (the display is deferred in Phase 0).

## BLE telemetry packet schema

The BLE notification formats decoded by `lib/models/telemetry_data.dart`
(telemetry, versions 2, 3 and 4), `lib/models/imu_block.dart` (the IMU
sample block), `lib/models/gps_block.dart` (the GPS block) and
`lib/models/vehicle_signal_block.dart` (the D-066 vehicle-signal block, records
keyed by DID, physical values through the generated catalog), plus the GATT
UUIDs and MTU, are defined once, in
`vehicle-defs` `ble/ble_schema.json` (D-061). This repo does not copy it:
the `external/vehicle-defs` submodule provides the generated Dart path
package `vehicle_defs` (`external/vehicle-defs/gen/dart/vehicle_defs`,
`import 'package:vehicle_defs/vehicle_defs.dart'`), and the decoders only read its
constants. After cloning, fetch the submodule first:

```
git submodule update --init
```

The tests build packets byte by byte from the generated offsets; a layout
change is a defs change plus a version bump, never a hand edit here.

## Ride session files and vehicle-server upload

Recording a ride writes `meta.json`, `telemetry.csv`, `events.csv`,
`summary.json` and (when the connected device sends IMU, GPS or vehicle-signal
data) `imu.csv`, `gps.csv` and `signals.csv` to `<app documents>/sessions/<session_id>/` -- see
`docs/session-format.md` for the exact contract shared with `vehicle-server`.
GPS is speed and heading only (D-060), and its characteristic needs the phone
to be paired (bonded) with the bike (D-062): on Android the app starts the
pairing on connect; telemetry, IMU and the vehicle-signal characteristic work
without it (firmware without a characteristic is simply not subscribed to).
`signals.csv` holds engine data only, so the D-063 local-only rule is for
`gps.csv` alone. Sessions can be shared locally
at any time; uploading them to a configured `vehicle-server` is a separate,
optional action (Settings screen sets the server URL/API token) and never
blocks recording or sharing.

### Security notes and known limitations

- **Cleartext http (C-2).** The manifest permits cleartext because Android's
  network security config cannot express IP ranges, and the desk setup talks
  to a laptop by LAN IP. The restriction is in Dart
  (`lib/services/token_guard.dart`): the bearer token and ride data are sent
  over `http://` only to loopback, private (RFC 1918 / ULA), link-local or
  `.local` hosts; anything else needs `https://`. User-installed CAs are not
  trusted.
- **Backups (C-3).** `allowBackup` is off and the data-extraction rules
  exclude everything: sessions hold GPS tracks (D-063).
- **Signing (C-3).** The release build, and the CI artifact
  `vehicle-mobile-apk-debug-signed`, use the Android **debug** key. That is
  fine for workshop installs only; a real release keystore (kept in CI
  secrets, never committed) is required before any distribution, and
  existing installs cannot be updated across a signing-key change.
- **BLE peer selection (C-10, known limitation).** The app connects to the
  first advertiser whose name contains `Honda-CL250`; telemetry and IMU
  characteristics need no bond, so a nearby device with that name could feed
  fake data into a recorded ride. Only the GPS characteristic requires
  bonding (D-062). Not a safety issue (the phone is not safety-relevant), but
  pinning the bonded device id / filtering by service UUID is a follow-up.
- **Telematics write (C-11).** `|` and line breaks are replaced by a space in
  song/artist text because the receiver has no escape for them; the BLE
  schema is unchanged.

## Ride history

The Record screen's app-bar **Server rides** action opens the read-only ride
history. It lists the sessions stored by `vehicle-server`, newest first, with
up to two chosen columns; a date range filters the request and a row opens that
session's stored ride summary (scalars, binned charts and the not-available
signals). An uploaded local session also shows a **Ride summary** action.

Both screens read `GET /rides` and `GET /sessions/{id}/summary` from the server
URL and API token set in Settings. They are read-only: nothing is written,
recomputed or deleted on the server.

## Bring-up check

A session that was uploaded to `vehicle-server` also has a read-only **Bring-up check**:
from the Record screen's session actions, or from the ride summary's app bar. The phone
shows the server's answer for one gate -- B0 (bench: report status, IMU gaps and the
at-rest check), V0 (vehicle: ECU present, every polled DID valid, no latch or bus-off) and
V1 (the V0 CAN health over at least 5 min plus the manual throttle blip); the exact
criteria are in `external/vehicle-defs/docs/hardware-integration.md` §6. The screen renders
the server's `verdict`, `checks`, `needs_you` and `warnings` and computes nothing itself.
It needs a `vehicle-server` with the bring-up route (`GET /sessions/{id}/bringup`, server#50).

## Commands

```
git submodule update --init   # vehicle-defs, needed by the vehicle_defs path package
flutter pub get
flutter analyze
flutter test
```

## License

MIT, see `LICENSE` (D-036).
