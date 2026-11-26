import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:vehicle_mobile/models/live_alert.dart';
import 'package:vehicle_mobile/services/alerts/alert_http.dart';
import 'package:vehicle_mobile/services/alerts/alert_opener.dart';
import 'package:vehicle_mobile/services/alerts/alert_prefs.dart';
import 'package:vehicle_mobile/services/alerts/sse.dart';
import 'package:vehicle_mobile/services/notifications_client.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/auth_events.dart';

/// How long a banner may stay on top of the live readouts (D-130 item 4); the
/// inbox keeps the history. A `clear` hides it earlier.
const Duration p1BannerMaxDisplay = Duration(seconds: 30);
const Duration p2BannerMaxDisplay = Duration(seconds: 12);

/// Reconnect delays 1, 2, 4, 8, 15, 30 s (then 30 s).
Duration alertBackoff(int attempt) {
  const steps = [1, 2, 4, 8, 15, 30];
  return Duration(seconds: steps[math.min(attempt, steps.length - 1)]);
}

/// Subscribes to `GET /alerts/stream` (D-129 items 3 and 4) while the app is
/// signed in and in the foreground (or recording), and keeps the alert that
/// should be on screen. Informational only (invariant 3): it never touches a
/// safety output and the stream is read-only.
class AlertController extends ChangeNotifier {
  AlertController({
    required this.settingsStore,
    AlertOpener? opener,
    this.prefs = const AlertPrefs(),
    this.onReconnect,
    this.onSpeak,
    this.locale,
    Duration Function(int attempt)? backoff,
    this.p1Display = p1BannerMaxDisplay,
    this.p2Display = p2BannerMaxDisplay,
  })  : _opener = opener ?? openAlertStream,
        _backoff = backoff ?? alertBackoff;

  final AppSettingsStore settingsStore;
  final AlertPrefs prefs;
  final AlertOpener _opener;
  final Duration Function(int attempt) _backoff;
  final Duration p1Display;
  final Duration p2Display;

  /// Called after every (re)connect: there is no replay, so the inbox is
  /// pulled again (`GET /notifications`).
  final Future<void> Function()? onReconnect;

  /// Called for an alert that asks to be spoken and is not muted.
  final Future<void> Function(LiveAlert alert)? onSpeak;

  /// UI language code, read at every (re)connect so a language change in the
  /// settings applies to the next connection; null or unsupported asks `en`.
  final String? Function()? locale;

  final Map<String, LiveAlert> _visible = {};
  final Map<String, Timer> _timers = {};
  Completer<void>? _sleeper;
  StreamSubscription<SseEvent>? _sub;
  Timer? _retry;
  bool _stopped = true;
  bool _disposed = false;
  int _attempt = 0;
  int _generation = 0;

  /// True while the stream is connected.
  bool get connected => _connected;
  bool _connected = false;

  /// The alert to show: P1 over P2, newest first; null when none.
  LiveAlert? get banner {
    LiveAlert? best;
    for (final a in _visible.values) {
      if (best == null ||
          (a.alertClass == LiveAlertClass.p1 &&
              best.alertClass != LiveAlertClass.p1) ||
          (a.alertClass == best.alertClass &&
              (a.ts ?? DateTime(0)).isAfter(best.ts ?? DateTime(0)))) {
        best = a;
      }
    }
    return best;
  }

  /// Opens the stream (idempotent).
  void start() {
    if (_disposed || !_stopped) return;
    _stopped = false;
    _attempt = 0;
    unawaited(_loop(++_generation));
  }

  /// Closes the stream (app in the background, signed out).
  void stop() {
    _stopped = true;
    _generation++;
    _retry?.cancel();
    _retry = null;
    final sleeper = _sleeper;
    _sleeper = null;
    if (sleeper != null && !sleeper.isCompleted) sleeper.complete();
    _sub?.cancel();
    _sub = null;
    if (_connected) {
      _connected = false;
      _notify();
    }
  }

  Future<void> _loop(int generation) async {
    while (!_stopped && generation == _generation && !_disposed) {
      final settings = await settingsStore.load();
      final token = settings.apiToken ?? '';
      if (!settings.isServerConfigured || token.isEmpty) {
        await _sleep(const Duration(seconds: 30), generation);
        continue;
      }
      final base = settings.serverBaseUrl!.trim();
      final url = Uri.parse(
          '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}/alerts/stream')
          .replace(queryParameters: {
        'locale': notificationsLocaleParam(locale?.call() ?? 'en'),
      });
      try {
        final bytes = await _opener(url, {
          'Authorization': 'Bearer $token',
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        });
        if (_stopped || generation != _generation) {
          unawaited(bytes.listen((_) {}).cancel());
          break;
        }
        _connected = true;
        _attempt = 0;
        _notify();
        unawaited(_pullInbox());
        final done = Completer<void>();
        _sub = parseSse(bytes).listen(
          _onEvent,
          onError: (Object _) {
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
        await done.future;
      } on AlertHttpException catch (e) {
        if (e.statusCode == 401) {
          AuthEvents.emit(AuthEvent.unauthorized);
          _stopped = true;
        } else if (e.statusCode == 404) {
          // An older server without the stream: stay quiet.
          _stopped = true;
        }
      } catch (_) {
        // Unreachable or dropped: retry below.
      }
      _connected = false;
      _sub = null;
      _notify();
      if (_stopped || generation != _generation) break;
      await _sleep(_backoff(_attempt++), generation);
    }
  }

  Future<void> _sleep(Duration d, int generation) {
    final c = _sleeper = Completer<void>();
    _retry = Timer(d, () {
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

  Future<void> _pullInbox() async {
    try {
      await onReconnect?.call();
    } catch (_) {
      // The inbox is pulled again by its own poll.
    }
  }

  void _onEvent(SseEvent e) {
    if (e.event != 'alert' && e.event != 'clear') return;
    Object? json;
    try {
      json = jsonDecode(e.data);
    } catch (_) {
      return;
    }
    final alert = LiveAlert.tryParse(e.event, json);
    if (alert == null) return;
    unawaited(_handle(alert));
  }

  Future<void> _handle(LiveAlert alert) async {
    if (alert.isClear) {
      _hide(alert.key);
      return;
    }
    final types = await prefs.remember(alert);
    final muted = types[alert.ruleId]?.muted ?? false;
    final p1 = alert.alertClass == LiveAlertClass.p1;
    // A P1 type is only ever muted from voice to banner (D-129 item 5); a
    // muted P2 type shows nothing live (the inbox keeps it).
    if (!p1 && muted) return;
    _visible[alert.key] = alert;
    _timers[alert.key]?.cancel();
    _timers[alert.key] =
        Timer(p1 ? p1Display : p2Display, () => _hide(alert.key));
    _notify();
    if (alert.speak && !(p1 && muted)) {
      try {
        await onSpeak?.call(alert);
      } catch (_) {
        // Speech failing is never fatal.
      }
    }
  }

  void _hide(String key) {
    _timers.remove(key)?.cancel();
    if (_visible.remove(key) != null) _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }
}
