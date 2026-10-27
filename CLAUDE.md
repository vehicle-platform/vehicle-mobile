# CLAUDE.md — vehicle-mobile

@.claude/PLATFORM-RULES.md

## What this repo is

The phone companion app, in **Flutter** (D-022). Starting point: the legacy `HondaCl250_Telemetry/mobile_app/flutter_app` (BLE client + decoder + dashboard), ported per D-023. Scope: settings, ride history/reports, park-mode alarm notifications, profile selection. Talks to the vehicle over BLE/Wi-Fi via `vehicle-connectivity-node`, and to the `vehicle-server` API for historical data.

## What this repo is NOT / rules

- **It is not involved in anything safety-critical.** The system works fully without the phone. When the phone connection drops, nothing changes on the vehicle side.
- Everything written from the phone to the vehicle is only a setting/preference (profile, brightness, etc.). Things like the safety threshold or unlocking the immobilizer do not belong in this repo; if asked to add them, ask the user.
- Signal names come from `vehicle-defs` (VSS paths), never hand-written.
- The BLE packet layout of every block (telemetry, IMU, GPS and the D-066 vehicle-signal block; offsets, sizes, versions, sentinels, flag masks, GATT UUIDs, MTU) comes only from the generated Dart path package `vehicle_defs` (`package:vehicle_defs/vehicle_defs.dart`, from `external/vehicle-defs/gen/dart/vehicle_defs`, source `ble/ble_schema.json`, D-061). No schema copy, no hand-written offsets or UUIDs; a layout change is a defs change plus a version bump. After cloning run `git submodule update --init`. The submodule is pinned to a defs release tag (CI checks it).
- `docs/session-format.md` is the contract shared with `vehicle-server`: change CSV columns on both sides together.
- This is the last repo to be set up during bring-up. Don't start development here before the earlier repos have settled.

## Build

```
git submodule update --init
flutter pub get
flutter analyze
flutter test
```

## Context

ARCHITECTURE §5, §7 · `../vehicle-defs/docs/hardware-architecture.md` §5b.4.
