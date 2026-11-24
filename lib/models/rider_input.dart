import 'dart:typed_data';

import 'package:vehicle_defs/vehicle_defs.dart';

// Rider-input block (handlebar push-to-talk, D-047, D-121 item 5). The layout
// (version, offsets, sizes, event values, flag bits) is NOT defined here: it
// comes only from the generated `vehicle_defs` Dart package
// (`BleRiderInputBlock`, `BleRiderInputOffsets`, `BleRiderInputEvent`,
// `BleRiderInputFlagBits`; source `ble/ble_schema.json` `riderInputBlock`).
// Informational only: nothing here is a safety output (invariant 3).

/// Thrown by [RiderInputBlockData.decode] for a payload that does not match
/// the schema (too short or an unknown version).
class RiderInputDecodeException implements Exception {
  RiderInputDecodeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The edge that caused a block (`event` of the schema).
enum RiderInputEdge { press, release, longPress }

/// One decoded rider-input block.
class RiderInputBlockData {
  const RiderInputBlockData({
    required this.seq,
    required this.deviceTimeMs,
    required this.edge,
    required this.buttonDown,
  });

  final int seq;
  final int deviceTimeMs;

  /// `null` for an `event` value outside the schema (the block is dropped).
  final RiderInputEdge? edge;

  /// `flags.buttonDown`: the debounced button state right after the event.
  final bool buttonDown;

  factory RiderInputBlockData.decode(Uint8List payload) {
    if (payload.length < BleRiderInputBlock.totalBytes) {
      throw RiderInputDecodeException(
          'rider-input block too short: ${payload.length} bytes');
    }
    final data = ByteData.sublistView(payload);
    final version = data.getUint8(BleRiderInputOffsets.version);
    if (version != BleRiderInputBlock.version) {
      throw RiderInputDecodeException(
          'rider-input block version $version not supported');
    }
    final event = data.getUint8(BleRiderInputOffsets.event);
    final edge = switch (event) {
      BleRiderInputEvent.press => RiderInputEdge.press,
      BleRiderInputEvent.release => RiderInputEdge.release,
      BleRiderInputEvent.longPress => RiderInputEdge.longPress,
      _ => null,
    };
    return RiderInputBlockData(
      seq: data.getUint8(BleRiderInputOffsets.seq),
      deviceTimeMs:
          data.getUint32(BleRiderInputOffsets.deviceTimeMs, Endian.little),
      edge: edge,
      buttonDown: (data.getUint8(BleRiderInputOffsets.flags) &
              BleRiderInputFlagBits.buttonDown) !=
          0,
    );
  }
}

/// What the app does for the rider's handlebar button.
enum RiderInputAction {
  /// Press: start listening (hold to talk, any hold length).
  startListening,

  /// Release after a long hold (a longPress block came during the hold):
  /// stop listening and send the transcript; an empty one does nothing.
  stopAndSend,

  /// Release after a tap (no longPress block during the hold): stop listening
  /// and send the transcript; an empty one repeats the last answer by voice.
  stopAfterTap,
}

/// Turns the rider-input notification stream into [RiderInputAction]s:
/// drops a block with the same seq as the previous one, counts lost blocks
/// `(seq - prev - 1) mod 256`, resynchronises from `flags.buttonDown` after a
/// loss and ignores a press older than [freshnessLimitMs] (compared with the
/// latest `deviceTimeMs` seen on the other blocks of the same node; with no
/// reference yet, the press is accepted).
class RiderInputTracker {
  RiderInputTracker({this.freshnessLimitMs = 2000});

  final int freshnessLimitMs;

  /// Blocks lost between two received blocks (sequence gaps).
  int lostBlocks = 0;

  /// Blocks dropped because their seq equalled the previous one.
  int duplicateBlocks = 0;

  /// Presses ignored as too old.
  int staleEvents = 0;

  /// Payloads that did not decode or carried an unknown event.
  int invalidBlocks = 0;

  int? _prevSeq;
  int? _referenceMs;
  bool _held = false;
  bool _longSeen = false;

  /// True while a press was accepted and its release has not come yet.
  bool get held => _held;

  /// Records the `deviceTimeMs` of any other block of the node (telemetry,
  /// IMU, GPS, vehicle signals): the freshness reference.
  void noteDeviceTime(int deviceTimeMs) {
    final ref = _referenceMs;
    if (ref == null || _isAfter(deviceTimeMs, ref)) {
      _referenceMs = deviceTimeMs & 0xFFFFFFFF;
    }
  }

  /// Forgets the sequence state (a new connection): the next block is not a
  /// loss or a duplicate of an old one.
  void reset() {
    _prevSeq = null;
    _referenceMs = null;
    _held = false;
    _longSeen = false;
  }

  /// uint32 wrap-aware "a is later than b".
  static bool _isAfter(int a, int b) {
    final diff = (a - b) & 0xFFFFFFFF;
    return diff != 0 && diff < 0x80000000;
  }

  bool _isStale(int deviceTimeMs) {
    final ref = _referenceMs;
    if (ref == null) return false;
    if (!_isAfter(ref, deviceTimeMs)) return false;
    return ((ref - deviceTimeMs) & 0xFFFFFFFF) > freshnessLimitMs;
  }

  List<RiderInputAction> accept(Uint8List payload) {
    final RiderInputBlockData block;
    try {
      block = RiderInputBlockData.decode(payload);
    } on RiderInputDecodeException {
      invalidBlocks++;
      return const [];
    }
    final edge = block.edge;
    if (edge == null) {
      invalidBlocks++;
      return const [];
    }
    final prev = _prevSeq;
    if (prev != null) {
      if (block.seq == prev) {
        duplicateBlocks++;
        return const [];
      }
      final gap = (block.seq - prev - 1) & 0xFF;
      lostBlocks += gap;
      _prevSeq = block.seq;
      if (gap > 0) return _resync(block, edge);
    } else {
      _prevSeq = block.seq;
    }
    return _apply(block, edge);
  }

  RiderInputAction _releaseAction() {
    _held = false;
    final action = _longSeen
        ? RiderInputAction.stopAndSend
        : RiderInputAction.stopAfterTap;
    _longSeen = false;
    return action;
  }

  /// After a loss the button state of the block is authoritative.
  List<RiderInputAction> _resync(
      RiderInputBlockData block, RiderInputEdge edge) {
    if (block.buttonDown && !_held) {
      // The press was lost: start only when this block is still fresh.
      if (_isStale(block.deviceTimeMs)) {
        staleEvents++;
        return const [];
      }
      _held = true;
      _longSeen = edge == RiderInputEdge.longPress;
      return const [RiderInputAction.startListening];
    }
    if (!block.buttonDown && _held) return [_releaseAction()];
    return _apply(block, edge);
  }

  List<RiderInputAction> _apply(
      RiderInputBlockData block, RiderInputEdge edge) {
    switch (edge) {
      case RiderInputEdge.press:
        if (_held) return const [];
        if (_isStale(block.deviceTimeMs)) {
          staleEvents++;
          return const [];
        }
        _held = true;
        _longSeen = false;
        return const [RiderInputAction.startListening];
      case RiderInputEdge.release:
        if (!_held) return const [];
        return [_releaseAction()];
      case RiderInputEdge.longPress:
        // Only the firmware saying the hold passed its long-press time: keep
        // listening. It makes the release a "long hold" instead of a tap.
        if (_held) _longSeen = true;
        return const [];
    }
  }
}
