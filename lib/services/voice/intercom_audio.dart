import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only bridge to the rider's Bluetooth intercom (D-121 item 5).
///
/// The intercom is an HFP headset: `acquire` routes the phone's audio to it
/// (API 31+: `setCommunicationDevice` with `MODE_IN_COMMUNICATION`; older:
/// Bluetooth SCO), `release` gives it back. On every other platform the
/// methods answer "not available" without touching the channel. An HFP
/// session pauses the intercom's group talk like a call does.
class IntercomAudio {
  IntercomAudio({MethodChannel? channel, bool? supported})
      : _channel = channel ?? const MethodChannel(channelName),
        _supported = supported ?? _isAndroid;

  static const String channelName = 'vehicle_mobile/intercom_audio';

  static final IntercomAudio instance = IntercomAudio();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final MethodChannel _channel;
  final bool _supported;

  /// True where the native side exists (Android).
  bool get supported => _supported;

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// A Bluetooth headset (HFP / SCO capable) is connected.
  Future<bool> isHeadsetConnected() async =>
      (await _call<bool>('status')) ?? false;

  /// Routes audio to the headset. `false`: no headset, no permission or the
  /// link did not come up in time; the phone's own microphone and speaker
  /// stay in use.
  Future<bool> acquire() async => (await _call<bool>('acquire')) ?? false;

  /// Gives the audio route and the audio mode back.
  Future<void> release() async {
    await _call<void>('release');
  }

  /// Speaks [text] with voice-communication audio attributes (the SCO link).
  /// Completes when it ended or was stopped; `false` when it could not speak.
  Future<bool> speak(String text, String languageTag) async =>
      (await _call<bool>('speak', {'text': text, 'language': languageTag})) ??
      false;

  Future<void> stopSpeaking() async {
    await _call<void>('stopSpeaking');
  }

  /// The app was cold-started by the headset's voice-command button
  /// (`android.intent.action.VOICE_COMMAND`); reading it clears the flag.
  Future<bool> consumeVoiceCommand() async =>
      (await _call<bool>('consumeVoiceCommand')) ?? false;

  /// Calls [onVoiceCommand] whenever the running app is brought forward by
  /// the voice-command intent.
  void listenVoiceCommand(VoidCallback onVoiceCommand) {
    if (!_supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'voiceCommand') onVoiceCommand();
      return null;
    });
  }

  void stopListeningVoiceCommand() {
    if (_supported) _channel.setMethodCallHandler(null);
  }
}
