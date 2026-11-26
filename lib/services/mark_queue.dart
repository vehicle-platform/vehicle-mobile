import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/models/ride_mark.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/marks_client.dart';

/// Persisted offline queue for rider event marks (G4-4 / T68).
///
/// Marks created without connectivity stay in [SharedPreferences], deduplicated
/// by [RideMark.id], and are retried on the next mark tap or explicit [flush].
class MarkQueue {
  MarkQueue({
    MarksClient? client,
    AppSettingsStore settingsStore = const AppSettingsStore(),
    DateTime Function()? clock,
    Random? random,
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

  String newId() {
    final ms = _clock().toUtc().millisecondsSinceEpoch;
    final suffix = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'm_${ms}_$suffix';
  }

  /// Creates a mark at the current UTC timestamp, queues it (deduplicated by
  /// `id`), and immediately attempts to flush. Returns `true` when the newly
  /// created mark was delivered to the server right away, `false` if it remains
  /// queued offline.
  Future<bool> recordAndSend(RideMarkKind kind, {String? note}) async {
    final mark = RideMark(
      id: newId(),
      tUtcMs: _clock().toUtc().millisecondsSinceEpoch,
      kind: kind,
      note: note,
    );
    return enqueue(mark);
  }

  /// Persists [mark] unless another queued mark already has [mark.id], then
  /// tries to flush the queue. Returns `true` if [mark] is no longer pending
  /// after the flush attempt.
  Future<bool> enqueue(RideMark mark) async {
    final items = await pending();
    if (!items.any((existing) => existing.id == mark.id)) {
      items.add(mark);
      await _save(items);
    }
    await flush();
    final remaining = await pending();
    return !remaining.any((item) => item.id == mark.id);
  }

  /// Loads all currently queued marks (dropping malformed entries safely).
  Future<List<RideMark>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      pendingCount.value = 0;
      return <RideMark>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        pendingCount.value = 0;
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
      pendingCount.value = out.length;
      return out;
    } on FormatException {
      pendingCount.value = 0;
      return <RideMark>[];
    }
  }

  /// Attempts to upload every queued mark in FIFO order. Returns the number of
  /// marks successfully delivered in this pass.
  Future<int> flush() async {
    final items = await pending();
    if (items.isEmpty) return 0;
    final settings = await _settingsStore.load();
    if (!settings.isServerConfigured) return 0;
    final baseUrl = settings.serverBaseUrl!;
    final token = settings.apiToken ?? '';
    var delivered = 0;
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
        // Permanent server rejection or duplicate conflict: drop so queue does not wedge.
      } else {
        // Offline / timeout / 401 / 5xx: keep this and subsequent marks for later retry.
        remaining.add(mark);
        stop = true;
      }
    }
    await _save(remaining);
    return delivered;
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
    pendingCount.value = items.length;
  }

  void dispose() {
    pendingCount.dispose();
  }
}
