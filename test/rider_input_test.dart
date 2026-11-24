import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_defs/vehicle_defs.dart';

import 'package:vehicle_mobile/models/rider_input.dart';

/// Builds a rider-input block only from the generated offsets and sizes.
Uint8List block({
  required int seq,
  required int deviceTimeMs,
  required int event,
  bool down = false,
  int version = BleRiderInputBlock.version,
}) {
  final bytes = Uint8List(BleRiderInputBlock.totalBytes);
  final data = ByteData.sublistView(bytes);
  data.setUint8(BleRiderInputOffsets.version, version);
  data.setUint8(BleRiderInputOffsets.seq, seq);
  data.setUint32(
      BleRiderInputOffsets.deviceTimeMs, deviceTimeMs, Endian.little);
  data.setUint8(BleRiderInputOffsets.event, event);
  data.setUint8(
      BleRiderInputOffsets.flags, down ? BleRiderInputFlagBits.buttonDown : 0);
  return bytes;
}

const press = BleRiderInputEvent.press;
const release = BleRiderInputEvent.release;
const longPress = BleRiderInputEvent.longPress;

void main() {
  group('RiderInputBlockData.decode', () {
    test('reads every field with the generated layout', () {
      final decoded = RiderInputBlockData.decode(
          block(seq: 7, deviceTimeMs: 123456, event: press, down: true));
      expect(decoded.seq, 7);
      expect(decoded.deviceTimeMs, 123456);
      expect(decoded.edge, RiderInputEdge.press);
      expect(decoded.buttonDown, isTrue);
    });

    test('rejects a short payload and an unknown version', () {
      expect(() => RiderInputBlockData.decode(Uint8List(3)),
          throwsA(isA<RiderInputDecodeException>()));
      expect(
          () => RiderInputBlockData.decode(
              block(seq: 0, deviceTimeMs: 0, event: press, version: 9)),
          throwsA(isA<RiderInputDecodeException>()));
    });

    test('an unknown event value has no edge', () {
      expect(
          RiderInputBlockData.decode(block(seq: 0, deviceTimeMs: 0, event: 77))
              .edge,
          isNull);
    });
  });

  group('RiderInputTracker', () {
    test('press starts, release sends, long press repeats', () {
      final t = RiderInputTracker();
      expect(
          t.accept(block(seq: 1, deviceTimeMs: 1000, event: press, down: true)),
          [RiderInputAction.startListening]);
      expect(t.held, isTrue);
      expect(t.accept(block(seq: 2, deviceTimeMs: 1500, event: release)),
          [RiderInputAction.stopAndSend]);
      expect(t.held, isFalse);
      expect(
          t.accept(block(seq: 3, deviceTimeMs: 2000, event: press, down: true)),
          [RiderInputAction.startListening]);
      expect(
          t.accept(
              block(seq: 4, deviceTimeMs: 3000, event: longPress, down: true)),
          [RiderInputAction.repeatLast]);
      // The release after a long press is not a send.
      expect(
          t.accept(block(seq: 5, deviceTimeMs: 3200, event: release)), isEmpty);
    });

    test('a block with the same seq as the previous one is dropped', () {
      final t = RiderInputTracker();
      final first = block(seq: 10, deviceTimeMs: 100, event: press, down: true);
      expect(t.accept(first), hasLength(1));
      expect(t.accept(first), isEmpty);
      expect(t.duplicateBlocks, 1);
      expect(t.lostBlocks, 0);
    });

    test('counts lost blocks and wraps at 255', () {
      final t = RiderInputTracker();
      t.accept(block(seq: 254, deviceTimeMs: 100, event: press, down: true));
      t.accept(block(seq: 255, deviceTimeMs: 200, event: release));
      expect(t.lostBlocks, 0);
      // 0 and 1 lost, 2 arrives.
      t.accept(block(seq: 2, deviceTimeMs: 300, event: press, down: true));
      expect(t.lostBlocks, 2);
    });

    test('a lost press followed by a long press still repeats', () {
      final t = RiderInputTracker();
      t.accept(block(seq: 1, deviceTimeMs: 100, event: release));
      // seq 2 (the press) lost; the longPress at seq 3 shows the button down.
      final actions = t.accept(
          block(seq: 3, deviceTimeMs: 900, event: longPress, down: true));
      expect(t.lostBlocks, 1);
      expect(actions, contains(RiderInputAction.repeatLast));
    });

    test(
        'a lost release stops listening when the next block shows the button up',
        () {
      final t = RiderInputTracker();
      t.accept(block(seq: 1, deviceTimeMs: 100, event: press, down: true));
      // The release (seq 2) is lost; the next press shows... button up on a
      // block that carries a release flag state: use a second release.
      final actions =
          t.accept(block(seq: 3, deviceTimeMs: 600, event: release));
      expect(t.lostBlocks, 1);
      expect(actions, [RiderInputAction.stopAndSend]);
      expect(t.held, isFalse);
    });

    test('a long press after lost blocks ends the hold and repeats', () {
      final t = RiderInputTracker();
      t.accept(block(seq: 1, deviceTimeMs: 100, event: press, down: true));
      // Release (2) and press (3) lost; block 4 is a longPress with the button down: still held.
      final actions = t.accept(
          block(seq: 4, deviceTimeMs: 900, event: longPress, down: true));
      expect(t.lostBlocks, 2);
      expect(actions, [RiderInputAction.repeatLast]);
    });

    test(
        'a press older than the freshness limit is ignored, a fresh one is not',
        () {
      final t = RiderInputTracker(freshnessLimitMs: 2000);
      t.noteDeviceTime(50000);
      expect(
          t.accept(
              block(seq: 1, deviceTimeMs: 40000, event: press, down: true)),
          isEmpty);
      expect(t.staleEvents, 1);
      expect(t.held, isFalse);
      // Its release does not send anything either.
      expect(t.accept(block(seq: 2, deviceTimeMs: 40300, event: release)),
          isEmpty);
      expect(
          t.accept(
              block(seq: 3, deviceTimeMs: 49500, event: press, down: true)),
          [RiderInputAction.startListening]);
    });

    test('with no reference time a press is accepted', () {
      final t = RiderInputTracker();
      expect(t.accept(block(seq: 1, deviceTimeMs: 5, event: press, down: true)),
          [RiderInputAction.startListening]);
    });

    test('freshness survives the uint32 wrap of the node clock', () {
      final t = RiderInputTracker();
      t.noteDeviceTime(0xFFFFFFF0);
      t.noteDeviceTime(0x00000010); // wrapped: later than 0xFFFFFFF0
      expect(
          t.accept(block(
              seq: 1, deviceTimeMs: 0xFFFFFFF8, event: press, down: true)),
          [RiderInputAction.startListening]);
      final t2 = RiderInputTracker(freshnessLimitMs: 100);
      t2.noteDeviceTime(0x00001000);
      expect(
          t2.accept(block(
              seq: 1, deviceTimeMs: 0xFFFFFF00, event: press, down: true)),
          isEmpty);
      expect(t2.staleEvents, 1);
    });

    test('a stale release is still honoured', () {
      final t = RiderInputTracker();
      t.accept(block(seq: 1, deviceTimeMs: 1000, event: press, down: true));
      t.noteDeviceTime(60000);
      expect(t.accept(block(seq: 2, deviceTimeMs: 1500, event: release)),
          [RiderInputAction.stopAndSend]);
    });

    test('invalid payloads and unknown events are counted and dropped', () {
      final t = RiderInputTracker();
      expect(t.accept(Uint8List(2)), isEmpty);
      expect(t.accept(block(seq: 1, deviceTimeMs: 0, event: 9)), isEmpty);
      expect(t.invalidBlocks, 2);
    });

    test('reset forgets the sequence so a reconnect is not a loss', () {
      final t = RiderInputTracker();
      t.accept(block(seq: 200, deviceTimeMs: 100, event: release));
      t.reset();
      t.accept(block(seq: 3, deviceTimeMs: 100, event: release));
      expect(t.lostBlocks, 0);
    });
  });
}
