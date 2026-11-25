import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'package:vehicle_mobile/models/app_notification.dart';
import 'package:vehicle_mobile/services/notifications/local_notifier.dart';
import 'package:vehicle_mobile/services/notifications/notification_sync.dart';

/// Android: system notifications through flutter_local_notifications.
/// Other platforms (macOS, iOS, ...) stay in-app.
LocalNotifier createLocalNotifier() =>
    Platform.isAndroid ? AndroidLocalNotifier() : const NoopLocalNotifier();

class AndroidLocalNotifier implements LocalNotifier {
  AndroidLocalNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  @override
  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      notificationChannelId,
      notificationChannelName,
      importance: Importance.defaultImportance,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      criticalChannelId,
      criticalChannelName,
      importance: Importance.high,
    ));
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> show(AppNotification notification) async {
    await init();
    final critical = notification.isCritical;
    await _plugin.show(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          critical ? criticalChannelId : notificationChannelId,
          critical ? criticalChannelName : notificationChannelName,
          importance: critical ? Importance.high : Importance.defaultImportance,
          priority: critical ? Priority.high : Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(notification.body),
        ),
      ),
    );
  }
}

const String _backgroundTaskName = 'vehicle_notifications_pull';
const String _backgroundUniqueName = 'vehicle_notifications_pull_periodic';

/// Entry point of the WorkManager isolate: pulls new notifications and shows
/// each one as a system notification (the id check of [NotificationSync]
/// keeps an entry from showing twice).
@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final notifier = AndroidLocalNotifier();
      final result = await NotificationSync().pull();
      for (final n in result.fresh) {
        if (!n.read) await notifier.show(n);
      }
    } catch (_) {
      // A failed pull is retried at the next period; never crash the worker.
    }
    return true;
  });
}

/// Android: a periodic pull (WorkManager's minimum period is 15 minutes) while
/// the app is closed. A no-op elsewhere.
Future<void> registerBackgroundPull() async {
  if (!Platform.isAndroid) return;
  await Workmanager().initialize(notificationCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _backgroundUniqueName,
    _backgroundTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

Future<void> cancelBackgroundPull() async {
  if (!Platform.isAndroid) return;
  await Workmanager().cancelByUniqueName(_backgroundUniqueName);
}
