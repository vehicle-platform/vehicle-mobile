import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:vehicle_mobile/services/voice/intercom_audio.dart';
import 'package:vehicle_mobile/services/voice/voice_permissions.dart';
import 'package:vehicle_mobile/services/voice/voice_ports.dart';
import 'package:vehicle_mobile/services/voice/voice_settings.dart';

enum VoiceState {
  idle,

  /// Asking for permissions and routing the audio.
  preparing,
  listening,

  /// Stopped by the rider; waiting for the final transcript.
  finishing,
  speaking,
}

/// Why the last voice action failed. The UI maps each to a localized message
/// (`assistantVoiceError*`); the controller carries no user-facing text.
enum VoiceError {
  /// The recogniser did not start in time.
  initTimeout,

  /// Nothing was heard.
  noSpeech,
  unavailable,

  /// Microphone permission denied or no recogniser on this device.
  permission,

  /// The recognition language is not installed.
  language,

  /// Recognition needs a network connection.
  network,
}

/// Where the sound goes (Android only): the rider's intercom or the phone.
enum VoiceRoute { intercom, phone }

/// What an empty transcript does after the rider stopped listening.
enum EmptyTranscript {
  /// Show the "did not hear you" error (mic button).
  message,

  /// Nothing (handlebar button after a long hold).
  nothing,

  /// Repeat the last answer (handlebar tap).
  repeat,
}

/// Voice front end of the ride assistant: microphone (speech to text), reading answers
/// aloud and the audio route to the rider's intercom (Android). It owns no
/// chat logic: a final transcript goes to [onTranscript], which sends it down
/// the normal `POST /chat` path. Informational only (invariant 3).
class VoiceController extends ChangeNotifier {
  VoiceController({
    SpeechRecognizerPort? recognizer,
    SpeechOutputPort? output,
    IntercomAudio? intercom,
    VoiceSettings settings = const VoiceSettings(),
    Future<void> Function()? ensureBluetoothPermission,
    Future<void> Function()? ensureMicrophonePermission,
    this.finalWait = const Duration(milliseconds: 1500),
    this.initTimeout = const Duration(seconds: 10),
  })  : _recognizer = recognizer ?? PluginSpeechRecognizer(),
        _output = output ?? PluginSpeechOutput(),
        _intercom = intercom ?? IntercomAudio.instance,
        _settings = settings,
        _ensureBluetooth =
            ensureBluetoothPermission ?? requestBluetoothConnectIfNeeded,
        _ensureMicrophone =
            ensureMicrophonePermission ?? requestMicrophoneIfNeeded;

  final SpeechRecognizerPort _recognizer;
  final SpeechOutputPort _output;
  final IntercomAudio _intercom;
  final VoiceSettings _settings;
  final Future<void> Function() _ensureBluetooth;
  final Future<void> Function() _ensureMicrophone;

  /// Bound on the recogniser start. It begins only after the microphone
  /// permission request finished, so it never cuts the permission prompt.
  final Duration initTimeout;

  /// How long to wait for the final transcript after the rider stopped.
  final Duration finalWait;

  /// Receives the final transcript (the screen sends it to `/chat`).
  void Function(String text)? onTranscript;

  /// Called when a tap of the handlebar button heard nothing.
  VoidCallback? onEmptyTap;
  EmptyTranscript _emptyPolicy = EmptyTranscript.message;

  VoiceState _state = VoiceState.idle;
  String _partial = '';
  VoiceError? _error;
  bool? _headset;
  bool _initialized = false;
  bool _routeHeld = false;
  bool _disposed = false;
  int _session = 0;
  int _speakGen = 0;
  bool _sessionDone = true;

  VoiceState get state => _state;
  bool get isListening => _state == VoiceState.listening;
  bool get isSpeaking => _state == VoiceState.speaking;

  /// Live partial transcript while listening.
  String get partial => _partial;

  /// Error of the last voice action, or null.
  VoiceError? get error => _error;

  /// Audio route; null where there is no routing (everything but Android).
  VoiceRoute? get route {
    if (!_intercom.supported) return null;
    return _headset == true ? VoiceRoute.intercom : VoiceRoute.phone;
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _set(VoiceState state) {
    _state = state;
    _notify();
  }

  /// Looks for a connected headset (the status chip).
  Future<void> refreshIntercom() async {
    if (!_intercom.supported) return;
    _headset = await _intercom.isHeadsetConnected();
    _notify();
  }

  // --- audio route ---------------------------------------------------------

  Future<bool> _acquireRoute() async {
    if (!_intercom.supported) return false;
    if (_routeHeld) return true;
    await _ensureBluetooth();
    final routed = await _intercom.acquire();
    _routeHeld = routed;
    _headset = routed || await _intercom.isHeadsetConnected();
    _notify();
    return routed;
  }

  Future<void> _releaseRoute() async {
    if (!_routeHeld) return;
    _routeHeld = false;
    await _intercom.release();
  }

  // --- listening -----------------------------------------------------------

  /// Mic button: start listening; while listening, stop and send; while
  /// speaking, stop the speech and start listening.
  Future<void> toggleMic() async {
    switch (_state) {
      case VoiceState.listening:
        await stopListening();
      case VoiceState.preparing:
      case VoiceState.finishing:
        break;
      case VoiceState.idle:
      case VoiceState.speaking:
        await startListening();
    }
  }

  Future<void> startListening() async {
    if (_state == VoiceState.listening ||
        _state == VoiceState.preparing ||
        _state == VoiceState.finishing) {
      return;
    }
    await stopSpeaking();
    final session = ++_session;
    _sessionDone = false;
    _emptyPolicy = EmptyTranscript.message;
    _error = null;
    _partial = '';
    _set(VoiceState.preparing);

    if (!_initialized) {
      try {
        await _ensureMicrophone();
      } catch (_) {
        // The recogniser asks again and reports a denial.
      }
      if (session != _session) return;
      var ok = false;
      var timedOut = false;
      try {
        ok = await _recognizer
            .initialize(onStatus: _onStatus, onError: _onError)
            .timeout(initTimeout, onTimeout: () {
          timedOut = true;
          return false;
        });
      } catch (_) {
        ok = false; // no speech plugin on this platform or browser
      }
      if (session != _session) return;
      if (timedOut) {
        _fail(VoiceError.initTimeout);
        return;
      }
      if (!ok) {
        _fail(VoiceError.permission);
        return;
      }
      _initialized = true;
    }
    await _acquireRoute();
    if (session != _session) {
      await _releaseRoute();
      return;
    }
    try {
      await _recognizer.listen(onResult: _onResult);
    } catch (_) {
      if (session == _session) _fail(VoiceError.unavailable);
      return;
    }
    if (session != _session) return;
    _set(VoiceState.listening);
  }

  void _onResult(String text, bool isFinal) {
    if (_sessionDone) return;
    if (_state != VoiceState.listening &&
        _state != VoiceState.finishing &&
        _state != VoiceState.preparing) {
      return;
    }
    _partial = text;
    if (isFinal) {
      unawaited(_complete(text));
    } else {
      _notify();
    }
  }

  void _onStatus(String status) {
    if (status == 'done' && !_sessionDone) {
      unawaited(_complete(_partial));
    }
  }

  void _onError(String code, bool permanent) {
    if (_sessionDone) return;
    final message = switch (code) {
      'error_permission' => VoiceError.permission,
      'error_language_unavailable' ||
      'error_language_not_supported' =>
        VoiceError.language,
      'error_network' ||
      'error_network_timeout' ||
      'error_server' =>
        VoiceError.network,
      'error_no_match' || 'error_speech_timeout' => VoiceError.noSpeech,
      _ => VoiceError.unavailable,
    };
    final silent = code == 'error_no_match' || code == 'error_speech_timeout';
    // Already released (finishing): nothing heard is an empty transcript.
    if (silent &&
        (_partial.trim().isNotEmpty || _state == VoiceState.finishing)) {
      unawaited(_complete(_partial));
      return;
    }
    _fail(message);
  }

  /// Rider stops listening (second tap, button released): the transcript so
  /// far, or the final one if it arrives within [finalWait], is sent.
  Future<void> stopListening(
      {EmptyTranscript onEmpty = EmptyTranscript.message}) async {
    if (_state != VoiceState.listening) return;
    _emptyPolicy = onEmpty;
    final session = _session;
    _set(VoiceState.finishing);
    try {
      await _recognizer.stop();
    } catch (_) {
      // The wait below falls back to the partial transcript.
    }
    await Future<void>.delayed(finalWait);
    if (session == _session && !_sessionDone) await _complete(_partial);
  }

  /// Ends listening without sending anything.
  Future<void> cancelListening() async {
    if (_state != VoiceState.listening &&
        _state != VoiceState.preparing &&
        _state != VoiceState.finishing) {
      return;
    }
    _session++;
    _sessionDone = true;
    _partial = '';
    try {
      await _recognizer.cancel();
    } catch (_) {
      // Already stopped.
    }
    await _releaseRoute();
    _set(VoiceState.idle);
  }

  Future<void> _complete(String text) async {
    if (_sessionDone) return;
    _sessionDone = true;
    _session++;
    final transcript = text.trim();
    _partial = '';
    await _releaseRoute();
    _set(VoiceState.idle);
    if (transcript.isEmpty) {
      switch (_emptyPolicy) {
        case EmptyTranscript.message:
          _error = VoiceError.noSpeech;
          _notify();
        case EmptyTranscript.nothing:
          break;
        case EmptyTranscript.repeat:
          onEmptyTap?.call();
      }
      return;
    }
    onTranscript?.call(transcript);
  }

  void _fail(VoiceError message) {
    _sessionDone = true;
    _session++;
    _partial = '';
    _error = message;
    unawaited(_recognizer.cancel().catchError((_) {}));
    unawaited(_releaseRoute());
    _set(VoiceState.idle);
  }

  // --- speaking ------------------------------------------------------------

  /// Reads [text] aloud when "read answers aloud" is on (or [force]).
  /// Completes with true when it was spoken to the end, false when it was
  /// skipped (setting off), interrupted or failed.
  Future<bool> speak(String text, {bool force = false}) async {
    if (text.trim().isEmpty) return false;
    if (!force && !await _settings.readAnswers()) return false;
    if (_disposed) return false;
    if (_state == VoiceState.listening ||
        _state == VoiceState.preparing ||
        _state == VoiceState.finishing) {
      return false;
    }
    final gen = ++_speakGen;
    _set(VoiceState.speaking);
    final routed = await _acquireRoute();
    if (gen != _speakGen) {
      // Interrupted while the route came up: give it back unless a listening
      // session started meanwhile and uses it.
      if (_state == VoiceState.idle) await _releaseRoute();
      return false;
    }
    try {
      await _output.speak(text, viaIntercom: routed);
    } catch (_) {
      // Speech failing is never fatal: the answer stays on screen.
    }
    final completed = gen == _speakGen;
    if (completed) {
      await _releaseRoute();
      if (_state == VoiceState.speaking) _set(VoiceState.idle);
    }
    return completed;
  }

  /// Stops speaking (tapped mic, new question, leaving the screen).
  Future<void> stopSpeaking() async {
    if (_state != VoiceState.speaking && !_routeHeld) {
      _speakGen++;
      return;
    }
    _speakGen++;
    try {
      await _output.stop();
    } catch (_) {
      // Already stopped.
    }
    if (_state == VoiceState.speaking) {
      await _releaseRoute();
      _set(VoiceState.idle);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _speakGen++;
    _session++;
    _sessionDone = true;
    unawaited(_recognizer.cancel().catchError((_) {}));
    unawaited(_output.stop().catchError((_) {}));
    if (_routeHeld) {
      _routeHeld = false;
      unawaited(_intercom.release());
    }
    super.dispose();
  }
}
