import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vehicle_mobile/services/voice/intercom_audio.dart';
import 'package:vehicle_mobile/services/voice/voice_ports.dart';

/// Scriptable speech recogniser: tests push results and statuses.
class FakeRecognizer implements SpeechRecognizerPort {
  bool initializeResult = true;
  int initializeCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  bool listening = false;
  Object? listenError;

  void Function(String status)? _onStatus;
  void Function(String code, bool permanent)? _onError;
  void Function(String text, bool isFinal)? _onResult;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String errorCode, bool permanent) onError,
  }) async {
    initializeCalls++;
    _onStatus = onStatus;
    _onError = onError;
    return initializeResult;
  }

  @override
  Future<void> listen(
      {required void Function(String text, bool isFinal) onResult}) async {
    listenCalls++;
    if (listenError != null) throw listenError!;
    listening = true;
    _onResult = onResult;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    listening = false;
  }

  void partial(String text) => _onResult?.call(text, false);
  void finalResult(String text) => _onResult?.call(text, true);
  void status(String status) => _onStatus?.call(status);
  void error(String code, {bool permanent = true}) =>
      _onError?.call(code, permanent);
}

/// Speech output that records what was spoken and finishes only when told to.
class FakeOutput implements SpeechOutputPort {
  final List<String> spoken = [];
  final List<bool> viaIntercom = [];
  int stopCalls = 0;

  /// When true, [speak] returns at once; otherwise it waits for [finish] or [stop].
  bool instant = false;
  Completer<void>? _current;

  @override
  Future<void> speak(String text, {bool viaIntercom = false}) async {
    spoken.add(text);
    this.viaIntercom.add(viaIntercom);
    if (instant) return;
    final completer = _current = Completer<void>();
    await completer.future;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    final current = _current;
    _current = null;
    if (current != null && !current.isCompleted) current.complete();
  }

  void finish() {
    final current = _current;
    _current = null;
    if (current != null && !current.isCompleted) current.complete();
  }

  bool get speaking => _current != null;
}

/// An [IntercomAudio] on a mock method channel that logs its calls.
class FakeIntercom {
  FakeIntercom({this.headset = true, this.routable = true})
      : channel = MethodChannel('test/intercom_${_count++}') {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'status':
          return headset;
        case 'acquire':
          return headset && routable;
        case 'consumeVoiceCommand':
          final pending = pendingVoiceCommand;
          pendingVoiceCommand = false;
          return pending;
        default:
          return null;
      }
    });
    audio = IntercomAudio(channel: channel, supported: true);
  }

  static int _count = 0;

  bool headset;
  bool routable;
  bool pendingVoiceCommand = false;
  final MethodChannel channel;
  final List<String> calls = [];
  late final IntercomAudio audio;

  /// Native -> Dart call, as MainActivity.onNewIntent does it.
  Future<void> nativeVoiceCommand() async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec()
          .encodeMethodCall(const MethodCall('voiceCommand')),
      (_) {},
    );
  }
}
