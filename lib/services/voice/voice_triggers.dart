import 'package:flutter/foundation.dart';

import 'package:vehicle_mobile/models/rider_input.dart';
import 'package:vehicle_mobile/services/voice/intercom_audio.dart';

/// What the app is asked to do by something other than the mic button: the
/// handlebar push-to-talk (BLE) and the intercom's voice-command button
/// (Android `VOICE_COMMAND` intent).
enum VoiceTrigger {
  /// Open Sürüş Asistanı and start listening.
  startListening,

  /// Button released after a long hold: send the question; empty does nothing.
  stopAndSend,

  /// Button released after a tap: send the question; empty repeats the last
  /// answer by voice.
  stopAfterTap,
}

VoiceTrigger triggerOfRiderInput(RiderInputAction action) => switch (action) {
      RiderInputAction.startListening => VoiceTrigger.startListening,
      RiderInputAction.stopAndSend => VoiceTrigger.stopAndSend,
      RiderInputAction.stopAfterTap => VoiceTrigger.stopAfterTap,
    };

/// Routes [VoiceTrigger]s to the Sürüş Asistanı screen. The shell sets [onNeedAssistant]
/// (select the Sürüş Asistanı tab); the screen [attach]es its handler once it exists.
/// A trigger that arrives before the screen is built waits and is delivered on
/// [attach] (a cold start from the voice-command button).
class VoiceTriggerBus {
  VoiceTriggerBus();

  static final VoiceTriggerBus instance = VoiceTriggerBus();

  void Function(VoiceTrigger trigger)? _handler;
  final List<VoiceTrigger> _pending = [];

  /// Called for triggers that need the Sürüş Asistanı screen in front.
  VoidCallback? onNeedAssistant;

  void emit(VoiceTrigger trigger) {
    if (trigger == VoiceTrigger.startListening) onNeedAssistant?.call();
    final handler = _handler;
    if (handler != null) {
      handler(trigger);
    } else if (trigger == VoiceTrigger.startListening) {
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
