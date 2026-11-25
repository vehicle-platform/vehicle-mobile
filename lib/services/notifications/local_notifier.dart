import 'package:vehicle_mobile/models/app_notification.dart';

/// Shows a notification in the system tray. Only Android has an
/// implementation (web and desktop stay in-app); tests use a fake.
abstract class LocalNotifier {
  /// Prepares channels; safe to call more than once.
  Future<void> init();

  /// Android 13+ runtime permission; true when notifications may be shown.
  Future<bool> requestPermission();

  Future<void> show(AppNotification notification);
}

/// Channel ids/names of the Android notifications (Turkish, user-visible).
const String notificationChannelId = 'vehicle_notifications';
const String notificationChannelName = 'Araç bildirimleri';
const String criticalChannelId = 'vehicle_notifications_critical';
const String criticalChannelName = 'Kritik araç bildirimleri';

class NoopLocalNotifier implements LocalNotifier {
  const NoopLocalNotifier();

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show(AppNotification notification) async {}
}
