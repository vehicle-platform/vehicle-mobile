import 'package:flutter/foundation.dart';

import 'package:vehicle_mobile/models/rider_input.dart';
import 'package:vehicle_mobile/services/voice/intercom_audio.dart';

/// What the app is asked to do by something other than the mic button: the
/// handlebar push-to-talk (BLE) and the intercom's voice-command button
/// (Android `VOICE_COMMAND` intent).
enum VoiceTrigger {
  /// Open Usta and start listening.
  startListening,

  /// Stop listening and send the question (button released).
  stopAndSend,

  /// Repeat the last answer by voice.
  repeatLast,
}

VoiceTrigger triggerOfRiderInput(RiderInputAction action) => switch (action) {
      RiderInputAction.startListening => VoiceTrigger.startListening,
      RiderInputAction.stopAndSend => VoiceTrigger.stopAndSend,
      RiderInputAction.repeatLast => VoiceTrigger.repeatLast,
    };

/// Routes [VoiceTrigger]s to the Usta screen. The shell sets [onNeedAssistant]
/// (select the Usta tab); the screen [attach]es its handler once it exists.
/// A trigger that arrives before the screen is built waits and is delivered on
/// [attach] (a cold start from the voice-command button).
class VoiceTriggerBus {
  VoiceTriggerBus();

  static final VoiceTriggerBus instance = VoiceTriggerBus();

  void Function(VoiceTrigger trigger)? _handler;
  final List<VoiceTrigger> _pending = [];

  /// Called for triggers that need the Usta screen in front.
  VoidCallback? onNeedAssistant;

  void emit(VoiceTrigger trigger) {
    if (trigger != VoiceTrigger.stopAndSend) onNeedAssistant?.call();
    final handler = _handler;
    if (handler != null) {
      handler(trigger);
    } else if (trigger != VoiceTrigger.stopAndSend) {
      _pending
        ..clear()
        ..add(trigger);
    }
  }

  /// Registers the screen's handler and delivers what is waiting.
  void attach(void Function(VoiceTrigger trigger) handler) {
    _handler = handler;
    final waiting = List<VoiceTrigger>.of(_pending);
    _pending.clear();
    for (final trigger in waiting) {
      handler(trigger);
    }
  }

  void detach(void Function(VoiceTrigger trigger) handler) {
    if (identical(_handler, handler)) _handler = null;
  }
}

/// Connects the Android voice-command intent to [bus]: a cold start
/// (`consumeVoiceCommand`) and a running app brought forward by it.
Future<void> bindVoiceCommandIntent(
    IntercomAudio audio, VoiceTriggerBus bus) async {
  audio.listenVoiceCommand(() => bus.emit(VoiceTrigger.startListening));
  if (await audio.consumeVoiceCommand()) bus.emit(VoiceTrigger.startListening);
}
