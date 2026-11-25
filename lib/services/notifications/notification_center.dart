import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:vehicle_mobile/models/app_notification.dart';
import 'package:vehicle_mobile/services/notifications/notification_sync.dart';
import 'package:vehicle_mobile/services/voice/critical_announcer.dart';

/// How often the foreground app pulls (D-123); a resume and a pull-to-refresh
/// pull immediately.
const Duration notificationPollInterval = Duration(seconds: 60);

/// The in-app inbox state (D-123): the notifications of the active host, the
/// unread badge count and the foreground poller. Critical notifications that
/// arrive are handed to the [announcer] once per id (D-121 item 7b); the
/// announcer itself skips the speech when voice output is off.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter({
    NotificationSync? sync,
    this.announcer,
    this.pollInterval = notificationPollInterval,
  }) : sync = sync ?? NotificationSync();

  final NotificationSync sync;
  final CriticalAnnouncer? announcer;
  final Duration pollInterval;

  final Map<int, AppNotification> _items = {};
  Timer? _timer;
  bool _disposed = false;
  bool _pulling = false;
  String? _hostId;

  /// null until the first pull answered; false when the host has no
  /// notification routes (the bell and inbox are then hidden).
  bool? _available;
  bool _loadedOnce = false;
  bool _signedOut = false;

  bool get available => _available != false && !_signedOut;

  /// Newest first.
  List<AppNotification> get items =>
      _items.values.toList()..sort((a, b) => b.id.compareTo(a.id));

  int get unreadCount => _items.values.where((n) => !n.read).length;

  /// Starts the 60 s foreground poll and pulls right away.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) {
      if (_available == false) return;
      unawaited(refresh());
    });
    unawaited(refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// App came back to the foreground: try again even when the host was marked
  /// unsupported (it may have been updated).
  void resumed() {
    _available = null;
    unawaited(refresh());
  }

  /// One pull. The first one per host (or [full]) rebuilds the inbox from
  /// id 0; later ones ask only for entries newer than the stored id.
  Future<void> refresh({bool full = false}) async {
    if (_pulling || _disposed) return;
    _pulling = true;
    try {
      final result = await sync.pull(full: full || !_loadedOnce);
      if (_disposed) return;
      switch (result.state) {
        case SyncState.ok:
          if (_hostId != result.hostId) {
            _items.clear();
            _hostId = result.hostId;
          }
          _available = true;
          _signedOut = false;
          _loadedOnce = true;
          for (final n in result.fetched) {
            _items[n.id] = n;
          }
          for (final n in result.fresh) {
            if (n.isCritical && !n.read) {
              unawaited(announcer?.announce(
                  HighSeverityFaultEvent(id: 'n${n.id}', title: n.title)));
            }
          }
        case SyncState.notSupported:
          _available = false;
          _items.clear();
        case SyncState.noSession:
        case SyncState.unauthorized:
          _signedOut = true;
          _items.clear();
          _loadedOnce = false;
        case SyncState.failed:
          break;
      }
      notifyListeners();
    } finally {
      _pulling = false;
    }
  }

  /// Marks one entry read locally first (the badge reacts at once), then on
  /// the server; a failed call is not retried (the next pull shows the truth).
  Future<void> markRead(int id) async {
    final n = _items[id];
    if (n == null || n.read) return;
    _items[id] = n.copyWith(read: true);
    notifyListeners();
    await sync.markRead(id);
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    for (final entry in _items.entries.toList()) {
      _items[entry.key] = entry.value.copyWith(read: true);
    }
    notifyListeners();
    await sync.markAllRead();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
