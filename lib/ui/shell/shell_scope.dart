import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/ui/notifications/notification_scope.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';

/// Hands the shell's actions to the screens inside it (D-130 item 2): the
/// settings route (the header gear on a phone) and the command bar.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.openSettings,
    required this.openCommandBar,
    required super.child,
  });

  final VoidCallback openSettings;
  final VoidCallback openCommandBar;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// App-bar actions every main screen shows: the notification bell and, below
/// 600 px (the phone layout, where the bar has no rail), the settings gear.
/// The rail carries Settings from 600 px up.
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = ShellScope.maybeOf(context);
    final compact = Breakpoints.isCompact(MediaQuery.sizeOf(context).width);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NotificationBell(),
        if (shell != null && compact)
          IconButton(
            tooltip: context.l10n.navSettings,
            icon: const Icon(Icons.tune),
            onPressed: shell.openSettings,
          ),
      ],
    );
  }
}
