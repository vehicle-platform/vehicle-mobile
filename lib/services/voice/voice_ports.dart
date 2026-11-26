import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:vehicle_mobile/services/voice/intercom_audio.dart';

/// BCP-47 tag of the speech language for an app language code (D-130): the
/// recogniser and the voice follow the language chosen in settings.
String voiceTagFor(String languageCode) =>
    languageCode == 'tr' ? 'tr-TR' : 'en-US';

/// Speech recognition behind a small port so tests use a fake.
abstract class SpeechRecognizerPort {
  /// Prepares the recogniser (asks for the microphone permission). `false`
  /// when it is unavailable or the permission was denied.
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String errorCode, bool permanent) onError,
  });

  /// Starts one listening session. [onResult] gets partial and final text.
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required String localeTag,
  });

  /// Ends the session; a final result may still arrive.
  Future<void> stop();

  /// Ends the session and discards its result.
  Future<void> cancel();
}

/// Speech output behind a small port so tests use a fake.
abstract class SpeechOutputPort {
  /// Speaks [text] and completes when it ended or was stopped. [viaIntercom]
  /// routes it with voice-communication audio attributes (Android SCO).
  Future<void> speak(String text,
      {bool viaIntercom = false, required String localeTag});

  /// Stops what is being spoken; the pending [speak] completes.
  Future<void> stop();
}

/// [SpeechRecognizerPort] on the `speech_to_text` plugin (Android, web,
/// macOS). Listens in the requested locale (en-US / tr-TR) when the platform
/// offers it, else in the device default.
class PluginSpeechRecognizer implements SpeechRecognizerPort {
  PluginSpeechRecognizer([SpeechToText? engine])
      : _engine = engine ?? SpeechToText();

  final SpeechToText _engine;
  List<String>? _localeIds;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String errorCode, bool permanent) onError,
  }) async {
    final ok = await _engine.initialize(
      onStatus: onStatus,
      onError: (SpeechRecognitionError e) => onError(e.errorMsg, e.permanent),
    );
    if (!ok) return false;
    try {
      _localeIds = [for (final l in await _engine.locales()) l.localeId];
    } catch (_) {
      // No locale list: the device default is used.
    }
    return true;
  }

  /// The platform's own spelling of [tag] (`tr_TR` vs `tr-TR`), or null when
  /// it is not offered.
  String? _resolve(String tag) {
    final wanted = tag.replaceAll('-', '_').toLowerCase();
    for (final id in _localeIds ?? const <String>[]) {
      if (id.replaceAll('-', '_').toLowerCase() == wanted) return id;
    }
    return null;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required String localeTag,
  }) =>
      _engine.listen(
        onResult: (SpeechRecognitionResult r) =>
            onResult(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: _resolve(localeTag),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );

  @override
  Future<void> stop() => _engine.stop();

  @override
  Future<void> cancel() => _engine.cancel();
}

/// [SpeechOutputPort] on `flutter_tts` (all platforms) and, only when the
/// audio is routed to the rider's Bluetooth headset, on the framework
/// `TextToSpeech` of the [IntercomAudio] channel: flutter_tts cannot set the
/// voice-communication audio attributes the SCO link needs.
class PluginSpeechOutput implements SpeechOutputPort {
  PluginSpeechOutput({FlutterTts? tts, IntercomAudio? intercom})
      : _tts = tts ?? FlutterTts(),
        _intercom = intercom ?? IntercomAudio.instance;

  final FlutterTts _tts;
  final IntercomAudio _intercom;
  Completer<void>? _done;
  bool _handlersSet = false;
  String? _language;
  bool _viaIntercom = false;

  Future<void> _configure(String localeTag) async {
    if (!_handlersSet) {
      _handlersSet = true;
      _tts.setCompletionHandler(_finish);
      _tts.setCancelHandler(_finish);
      _tts.setErrorHandler((_) => _finish());
    }
    if (_language == localeTag) return;
    _language = localeTag;
    try {
      await _tts.setLanguage(localeTag);
    } catch (_) {
      // The device default language stays.
    }
  }

  void _finish() {
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  @override
  Future<void> speak(String text,
      {bool viaIntercom = false, required String localeTag}) async {
    await stop();
    if (text.trim().isEmpty) return;
    _viaIntercom = viaIntercom && _intercom.supported;
    if (_viaIntercom) {
      final spoken = await _intercom.speak(text, localeTag);
      if (spoken) return;
      _viaIntercom = false;
    }
    await _configure(localeTag);
    final done = _done = Completer<void>();
    try {
      await _tts.speak(text);
    } catch (_) {
      _finish();
    }
    // Bounded wait: a platform that never reports completion must not hang.
    await done.future.timeout(const Duration(seconds: 90), onTimeout: _finish);
  }

  @override
  Future<void> stop() async {
    if (_viaIntercom) {
      _viaIntercom = false;
      await _intercom.stopSpeaking();
    }
    if (_done != null) {
      try {
        await _tts.stop();
      } catch (_) {
        // Already stopped.
      }
      _finish();
    }
  }
}
