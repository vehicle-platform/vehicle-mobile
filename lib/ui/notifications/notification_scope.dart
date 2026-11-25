import 'package:flutter/material.dart';

import 'package:vehicle_mobile/services/notifications/notification_center.dart';
import 'package:vehicle_mobile/ui/notifications/notifications_screen.dart';

/// Hands the [NotificationCenter] and the "ask the assistant" action to every
/// screen under the shell (D-123), so each app bar can show the bell.
class NotificationScope extends InheritedNotifier<NotificationCenter> {
  const NotificationScope({
    super.key,
    required NotificationCenter center,
    required this.onAsk,
    required super.child,
  }) : super(notifier: center);

  /// Opens the assistant with a prefilled [question] (and the ride [sessionId]).
  final void Function(String question, String? sessionId) onAsk;

  static NotificationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotificationScope>();
}

/// Bell with an unread badge for the app bar of every main screen. Hidden when
/// there is no scope or the host has no notification routes.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = NotificationScope.maybeOf(context);
    final center = scope?.notifier;
    if (scope == null || center == null || !center.available) {
      return const SizedBox.shrink();
    }
    final unread = center.unreadCount;
    return IconButton(
      tooltip: unread == 0 ? 'Bildirimler' : 'Bildirimler ($unread okunmamış)',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => NotificationScope(
          center: center,
          onAsk: scope.onAsk,
          child: const NotificationsScreen(),
        ),
      )),
    );
  }
}
