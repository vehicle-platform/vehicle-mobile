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
    test('tap: press starts, release without a longPress is a tap', () {
      final t = RiderInputTracker();
      expect(
          t.accept(block(seq: 1, deviceTimeMs: 1000, event: press, down: true)),
          [RiderInputAction.startListening]);
      expect(t.held, isTrue);
      expect(t.accept(block(seq: 2, deviceTimeMs: 1200, event: release)),
          [RiderInputAction.stopAfterTap]);
      expect(t.held, isFalse);
    });

    test('long hold: longPress mid-hold is ignored, release sends', () {
      final t = RiderInputTracker();
      t.accept(block(seq: 1, deviceTimeMs: 1000, event: press, down: true));
      expect(
          t.accept(
              block(seq: 2, deviceTimeMs: 1800, event: longPress, down: true)),
          isEmpty);
      expect(t.held, isTrue);
      expect(t.accept(block(seq: 3, deviceTimeMs: 6000, event: release)),
          [RiderInputAction.stopAndSend]);
      // The next hold is a tap again.
      t.accept(block(seq: 4, deviceTimeMs: 7000, event: press, down: true));
      expect(t.accept(block(seq: 5, deviceTimeMs: 7100, event: release)),
          [RiderInputAction.stopAfterTap]);
    });

    test('a longPress with no press seen does nothing', () {
      final t = RiderInputTracker();
      expect(
          t.accept(
              block(seq: 1, deviceTimeMs: 1000, event: longPress, down: true)),
          isEmpty);
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

    test(
        'a lost press: the longPress block shows the button down and starts listening',
        () {
      final t = RiderInputTracker();
      t.accept(block(seq: 1, deviceTimeMs: 100, event: release));
      // seq 2 (the press) lost.
      expect(
          t.accept(
              block(seq: 3, deviceTimeMs: 900, event: longPress, down: true)),
          [RiderInputAction.startListening]);
      expect(t.lostBlocks, 1);
      expect(t.accept(block(seq: 4, deviceTimeMs: 2000, event: release)),
          [RiderInputAction.stopAndSend]);
    });

    test(
        'a lost release stops listening when the next block shows the button up',
        () {
      final t = RiderInputTracker();
      t.accept(block(seq: 1, deviceTimeMs: 100, event: press, down: true));
      final actions =
          t.accept(block(seq: 3, deviceTimeMs: 600, event: release));
      expect(t.lostBlocks, 1);
      expect(actions, [RiderInputAction.stopAfterTap]);
      expect(t.held, isFalse);
    });

    test('a longPress after lost blocks keeps listening', () {
      final t = RiderInputTracker();
      t.accept(block(seq: 1, deviceTimeMs: 100, event: press, down: true));
      expect(
          t.accept(
              block(seq: 4, deviceTimeMs: 900, event: longPress, down: true)),
          isEmpty);
      expect(t.lostBlocks, 2);
      expect(t.held, isTrue);
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
          [RiderInputAction.stopAfterTap]);
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
