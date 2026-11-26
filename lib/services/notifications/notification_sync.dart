import 'package:vehicle_mobile/models/app_notification.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/notifications/notification_store.dart';
import 'package:vehicle_mobile/services/notifications_client.dart';

enum SyncState {
  /// Pulled (possibly nothing new).
  ok,

  /// No host or no session: nothing to pull.
  noSession,

  /// The host has no notification routes (404): hide the feature.
  notSupported,

  /// 401: the session ended (already reported on `AuthEvents`).
  unauthorized,

  /// Network or server trouble; try again later.
  failed,
}

class SyncResult {
  const SyncResult(this.state,
      {this.hostId, this.fetched = const [], this.fresh = const []});

  final SyncState state;
  final String? hostId;

  /// Everything the pull returned (new and old), for the inbox.
  final List<AppNotification> fetched;

  /// The entries newer than the last seen id: these are announced / shown as
  /// local notifications, exactly once.
  final List<AppNotification> fresh;
}

/// One pull of the inbox, shared by the foreground poller and the Android
/// background task: ask `since_id=<last seen>`, page through the answer, keep
/// the highest id (D-123). [full] asks from 0 to rebuild the inbox, while
/// `fresh` still contains only entries above the stored id.
class NotificationSync {
  NotificationSync({
    this.settingsStore = const AppSettingsStore(),
    NotificationsClient? client,
    this.store = const NotificationStore(),
    this.pageLimit = notificationsMaxLimit,
    this.maxPages = 10,
  }) : client = client ?? NotificationsClient();

  final AppSettingsStore settingsStore;
  final NotificationsClient client;
  final NotificationStore store;
  final int pageLimit;
  final int maxPages;

  /// [locale] gives the UI language code, read after the settings loaded (the
  /// shell learns its locale only after its first frame); the inbox texts are
  /// requested in that language.
  Future<SyncResult> pull({bool full = false, String? Function()? locale}) async {
    final AppSettings settings;
    try {
      settings = await settingsStore.load();
    } catch (_) {
      return const SyncResult(SyncState.failed);
    }
    final hostId = settings.hostId;
    final token = settings.apiToken ?? '';
    if (hostId == null || !settings.isServerConfigured || token.isEmpty) {
      return const SyncResult(SyncState.noSession);
    }
    final localeCode = locale?.call();
    final lastSeen = await store.lastSeenId(hostId);
    var since = full ? 0 : lastSeen;
    final byId = <int, AppNotification>{};
    for (var page = 0; page < maxPages; page++) {
      final result = await client.list(
          baseUrl: settings.serverBaseUrl!,
          token: token,
          sinceId: since,
          limit: pageLimit,
          locale: localeCode);
      switch (result.outcome) {
        case NotificationsOutcome.ok:
          break;
        case NotificationsOutcome.notSupported:
          return SyncResult(SyncState.notSupported, hostId: hostId);
        case NotificationsOutcome.unauthorized:
          return SyncResult(SyncState.unauthorized, hostId: hostId);
        default:
          return SyncResult(SyncState.failed, hostId: hostId);
      }
      for (final n in result.items) {
        byId[n.id] = n;
      }
      if (result.items.length < pageLimit) break;
      final next =
          result.items.map((n) => n.id).reduce((a, b) => a > b ? a : b);
      if (next <= since) break;
      since = next;
    }
    final fetched = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    final fresh = [
      for (final n in fetched)
        if (n.id > lastSeen) n
    ];
    if (fetched.isNotEmpty) {
      await store.saveLastSeenId(hostId, fetched.last.id);
    }
    return SyncResult(SyncState.ok,
        hostId: hostId, fetched: fetched, fresh: fresh);
  }

  Future<NotificationsResult> markRead(int id) async {
    final settings = await settingsStore.load();
    return client.markRead(
        baseUrl: settings.serverBaseUrl ?? '',
        token: settings.apiToken ?? '',
        id: id);
  }

  Future<NotificationsResult> markAllRead() async {
    final settings = await settingsStore.load();
    return client.markAllRead(
        baseUrl: settings.serverBaseUrl ?? '', token: settings.apiToken ?? '');
  }
}
