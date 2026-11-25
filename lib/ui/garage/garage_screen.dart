import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/app_notification.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/ui/faults/faults_screen.dart';
import 'package:vehicle_mobile/ui/notifications/notifications_screen.dart';
import 'package:vehicle_mobile/ui/shell/master_detail.dart';
import 'package:vehicle_mobile/ui/shell/shell_scope.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// Garage destination (D-130 item 2): the bike's health. The notification
/// inbox and the fault catalogue behind a two-way switch; on a wide window the
/// inbox opens an item in a detail pane.
class GarageScreen extends StatefulWidget {
  const GarageScreen({
    super.key,
    required this.settingsStore,
    this.twoPane = false,
    this.selected,
    this.onOpenNotification,
  });

  final AppSettingsStore settingsStore;

  /// The wide layout shows a detail pane for the selected notification.
  final bool twoPane;
  final AppNotification? selected;
  final ValueChanged<AppNotification>? onOpenNotification;

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

enum _GarageSection { inbox, faults }

class _GarageScreenState extends State<GarageScreen> {
  _GarageSection _section = _GarageSection.inbox;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.vehicle;
    final selected = widget.selected;
    final inbox = NotificationsScreen(
      embedded: true,
      onOpen: widget.twoPane ? widget.onOpenNotification : null,
    );
    final Widget body;
    if (_section == _GarageSection.faults) {
      body = FaultsScreen(settingsStore: widget.settingsStore, embedded: true);
    } else if (widget.twoPane) {
      body = MasterDetail(
        master: inbox,
        detail: selected == null
            ? null
            : NotificationDetailScreen(
                key: ValueKey(selected.id), notification: selected),
        emptyMessage: l.garageSelectItem,
      );
    } else {
      body = inbox;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navGarage),
        actions: const [HeaderActions()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(Spacing.touchTarget),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: SegmentedButton<_GarageSection>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  selectedBackgroundColor: t.surfaceRaised,
                  selectedForegroundColor: t.accent,
                ),
                segments: [
                  ButtonSegment(
                      value: _GarageSection.inbox,
                      label: Text(l.garageInbox)),
                  ButtonSegment(
                      value: _GarageSection.faults,
                      label: Text(l.garageFaults)),
                ],
                selected: {_section},
                onSelectionChanged: (s) => setState(() => _section = s.first),
              ),
            ),
          ),
        ),
      ),
      body: body,
    );
  }
}
