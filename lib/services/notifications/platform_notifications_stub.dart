import 'package:vehicle_mobile/services/notifications/local_notifier.dart';

/// Web: no system notifications and no background task; the inbox is in-app.
LocalNotifier createLocalNotifier() => const NoopLocalNotifier();

/// Web: nothing to schedule.
Future<void> registerBackgroundPull() async {}

/// Web: nothing to cancel.
Future<void> cancelBackgroundPull() async {}
