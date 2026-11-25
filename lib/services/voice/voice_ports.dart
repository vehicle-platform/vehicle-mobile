import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:vehicle_mobile/services/voice/intercom_audio.dart';

/// Preferred recognition and speech language of Sürüş Asistanı.
const String voiceLocaleTag = 'tr-TR';

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
  Future<void> speak(String text, {bool viaIntercom = false});

  /// Stops what is being spoken; the pending [speak] completes.
  Future<void> stop();
}

/// [SpeechRecognizerPort] on the `speech_to_text` plugin (Android, web,
/// macOS). Locale tr-TR when the platform offers it, else the device default.
class PluginSpeechRecognizer implements SpeechRecognizerPort {
  PluginSpeechRecognizer([SpeechToText? engine])
      : _engine = engine ?? SpeechToText();

  final SpeechToText _engine;
  String? _localeId;

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
      final locales = await _engine.locales();
      final wanted = voiceLocaleTag.replaceAll('-', '_').toLowerCase();
      for (final locale in locales) {
        if (locale.localeId.replaceAll('-', '_').toLowerCase() == wanted) {
          _localeId = locale.localeId;
          break;
        }
      }
    } catch (_) {
      // No locale list: the device default is used.
    }
    return true;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) =>
      _engine.listen(
        onResult: (SpeechRecognitionResult r) =>
            onResult(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: _localeId,
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
  bool _configured = false;
  bool _viaIntercom = false;

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    try {
      await _tts.setLanguage(voiceLocaleTag);
    } catch (_) {
      // The device default language stays.
    }
    _tts.setCompletionHandler(_finish);
    _tts.setCancelHandler(_finish);
    _tts.setErrorHandler((_) => _finish());
  }

  void _finish() {
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  @override
  Future<void> speak(String text, {bool viaIntercom = false}) async {
    await stop();
    if (text.trim().isEmpty) return;
    _viaIntercom = viaIntercom && _intercom.supported;
    if (_viaIntercom) {
      final spoken = await _intercom.speak(text, voiceLocaleTag);
      if (spoken) return;
      _viaIntercom = false;
    }
    await _configure();
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
