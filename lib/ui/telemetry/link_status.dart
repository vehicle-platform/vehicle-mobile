import 'package:flutter/widgets.dart' show Locale;

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/models/gps_block.dart';
import 'package:vehicle_mobile/models/telemetry_data.dart';

// Helpers that turn link / CAN / GPS state into short display text and a
// tone; they are unit tested directly (English by default).

/// Severity of a status item; the widget layer maps it to a token colour.
enum Tone { ok, warn, error, neutral, accent }

/// Text plus tone of one status item.
class StatusText {
  const StatusText(this.text, this.tone);

  final String text;
  final Tone tone;
}

AppLocalizations _en() => lookupAppLocalizations(const Locale('en'));

/// CAN bus state of the node's vehicle-bus controller. `null` means the
/// packet version carries no CAN health (version 2). [l] defaults to English
/// (unit tests); screens pass `context.l10n`.
StatusText canStateStatus(CanBusState? state, [AppLocalizations? l]) {
  l ??= _en();
  if (state == null) return StatusText(l.rideCanNa, Tone.neutral);
  return switch (state) {
    CanBusState.running => StatusText(l.rideCanRunning, Tone.ok),
    CanBusState.errorWarning => StatusText(l.rideCanErrorWarning, Tone.warn),
    CanBusState.busOff => StatusText(l.rideCanBusOff, Tone.error),
    CanBusState.stopped => StatusText(l.rideCanStopped, Tone.warn),
    CanBusState.notInstalled => StatusText(l.rideCanNotInstalled, Tone.neutral),
  };
}

/// GPS link: subscription state plus the newest fix, if any.
StatusText gpsStatus(GpsLinkStatus link, GpsBlock? block,
    [AppLocalizations? l]) {
  l ??= _en();
  switch (link.state) {
    case GpsLinkState.disconnected:
      return StatusText(l.rideGpsNone, Tone.neutral);
    case GpsLinkState.notOffered:
      return StatusText(l.rideGpsNotOffered, Tone.neutral);
    case GpsLinkState.subscribing:
      return StatusText(l.rideGpsPairing, Tone.warn);
    case GpsLinkState.failed:
      return StatusText(l.rideGpsPairPhone, Tone.warn);
    case GpsLinkState.subscribed:
      if (block == null) return StatusText(l.rideGpsWaiting, Tone.warn);
      return StatusText(l.rideGpsFix(block.fixTypeLabel, block.numSv),
          block.gnssFixOk ? Tone.ok : Tone.warn);
  }
}

/// `1234` -> `1234 ms`, `null` -> `--`.
String formatMs(int? ms) => ms == null ? '--' : '$ms ms';

/// Age text for a signal row: `120 ms`, `2.4 s`, or `--`.
String formatAge(int? ms) {
  if (ms == null) return '--';
  if (ms < 1000) return '$ms ms';
  return '${(ms / 1000).toStringAsFixed(1)} s';
}

/// `0xF40C`-style hex of a DID.
String didHex(int did) =>
    '0x${did.toRadixString(16).toUpperCase().padLeft(4, '0')}';

/// `0x31`-style hex of a negative response code.
String nrcHex(int nrc) =>
    '0x${nrc.toRadixString(16).toUpperCase().padLeft(2, '0')}';
