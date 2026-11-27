import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/models/ride_mark.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/marks_client.dart';

/// What happened to a mark handed to [MarkQueue.recordAndSend].
enum MarkSendOutcome {
  /// Delivered to the server (or the server already had it).
  sent,

  /// Kept in the persisted queue for a later retry.
  queued,

  /// The server permanently rejected it (422 / 409); it was dropped.
  rejected,
}

/// Persisted offline queue for rider event marks (G4-4 / T68).
///
/// Marks created without connectivity stay in [SharedPreferences] (they survive
/// backgrounding and an app restart), deduplicated by [RideMark.id]. While marks
/// are pending a timer retries with exponential backoff
/// ([retryBase] doubling up to [retryMax]); the timer is cancelled by
/// [dispose]. Every read-modify-write of the stored list runs under one lock,
/// so a tap during a running flush can neither be lost nor sent twice. A
/// permanent server rejection drops the mark and bumps [rejectedCount] so the UI
/// can tell the rider.
class MarkQueue {
  MarkQueue({
    MarksClient? client,
    AppSettingsStore settingsStore = const AppSettingsStore(),
    DateTime Function()? clock,
    Random? random,
    this.retryBase = const Duration(seconds: 5),
    this.retryMax = const Duration(minutes: 5),
  })  : _client = client ?? MarksClient(),
        _settingsStore = settingsStore,
        _clock = clock ?? (() => DateTime.now().toUtc()),
        _random = random ?? Random();

  static const String _storageKey = 'ride_mark_queue_v1';

  final MarksClient _client;
  final AppSettingsStore _settingsStore;
  final DateTime Function() _clock;
  final Random _random;
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  /// Number of marks dropped because the server permanently rejected them.
  final ValueNotifier<int> rejectedCount = ValueNotifier<int>(0);

  final Duration retryBase;
  final Duration retryMax;

  Future<void> _tail = Future<void>.value();
  final Set<String> _rejectedIds = <String>{};
  Timer? _retryTimer;
  int _attempt = 0;
  bool _disposed = false;

  /// Runs [action] after every earlier locked action finished.
  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  String newId() {
    final ms = _clock().toUtc().millisecondsSinceEpoch;
    final suffix = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'm_${ms}_$suffix';
  }

  /// Creates a mark at the current UTC timestamp, queues it (deduplicated by
  /// `id`), and immediately attempts to flush.
  Future<MarkSendOutcome> recordAndSend(RideMarkKind kind,
      {String? note}) async {
    final mark = RideMark(
      id: newId(),
      tUtcMs: _clock().toUtc().millisecondsSinceEpoch,
      kind: kind,
      note: note,
    );
    return enqueue(mark);
  }

  /// Persists [mark] unless another queued mark already has [mark.id], then
  /// tries to flush the queue.
  Future<MarkSendOutcome> enqueue(RideMark mark) async {
    await _locked(() async {
      final items = await pending();
      if (!items.any((existing) => existing.id == mark.id)) {
        items.add(mark);
        await _save(items);
      }
    });
    await flush();
    if (_rejectedIds.remove(mark.id)) return MarkSendOutcome.rejected;
    final remaining = await pending();
    return remaining.any((item) => item.id == mark.id)
        ? MarkSendOutcome.queued
        : MarkSendOutcome.sent;
  }

  /// Loads all currently queued marks (dropping malformed entries safely).
  Future<List<RideMark>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _setPending(0);
      return <RideMark>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _setPending(0);
        return <RideMark>[];
      }
      final seen = <String>{};
      final out = <RideMark>[];
      for (final item in decoded) {
        final mark = RideMark.fromJson(item);
        if (mark != null && seen.add(mark.id)) {
          out.add(mark);
        }
      }
      _setPending(out.length);
      return out;
    } on FormatException {
      _setPending(0);
      return <RideMark>[];
    }
  }

  /// Attempts to upload every queued mark in FIFO order. Returns the number of
  /// marks successfully delivered in this pass. Safe to call concurrently.
  Future<int> flush() => _locked(_flushLocked);

  Future<int> _flushLocked() async {
    if (_disposed) return 0;
    _retryTimer?.cancel();
    final items = await pending();
    if (items.isEmpty) {
      _attempt = 0;
      return 0;
    }
    final settings = await _settingsStore.load();
    if (!settings.isServerConfigured) return 0;
    final baseUrl = settings.serverBaseUrl!;
    final token = settings.apiToken ?? '';
    var delivered = 0;
    var rejected = 0;
    final remaining = <RideMark>[];
    var stop = false;
    for (final mark in items) {
      if (stop) {
        remaining.add(mark);
        continue;
      }
      final res = await _client.createMark(
        baseUrl: baseUrl,
        apiToken: token,
        mark: mark,
      );
      if (res.isSuccess) {
        delivered++;
      } else if (res.outcome == MarkCallOutcome.conflict ||
          res.outcome == MarkCallOutcome.invalid) {
        // Permanent server rejection: drop so the queue does not wedge, but
        // tell the UI.
        rejected++;
        _rejectedIds.add(mark.id);
      } else {
        // Offline / timeout / 401 / 5xx: keep this and subsequent marks.
        remaining.add(mark);
        stop = true;
      }
    }
    await _save(remaining);
    if (_disposed) return delivered;
    if (rejected > 0) rejectedCount.value += rejected;
    if (remaining.isEmpty || delivered > 0) _attempt = 0;
    if (remaining.isNotEmpty) _scheduleRetry();
    return delivered;
  }

  void _setPending(int n) {
    if (!_disposed) pendingCount.value = n;
  }

  void _scheduleRetry() {
    var delay = retryBase * (1 << _attempt.clamp(0, 16));
    if (delay > retryMax) delay = retryMax;
    _attempt++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(flush()));
  }

  Future<void> _save(List<RideMark> items) async {
    final prefs = await SharedPreferences.getInstance();
    if (items.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(
        _storageKey,
        jsonEncode(items.map((m) => m.toJson()).toList(growable: false)),
      );
    }
    if (!_disposed) pendingCount.value = items.length;
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    pendingCount.dispose();
    rejectedCount.dispose();
  }
}
