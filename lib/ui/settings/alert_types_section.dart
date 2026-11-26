import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/live_alert.dart';
import 'package:vehicle_mobile/services/alerts/alert_prefs.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';

/// Per-type mutes of the ride alerts (D-129 item 5). A critical (P1) type can
/// only be muted from voice to banner: its banner always shows. A warning (P2)
/// type can be hidden completely (the inbox keeps its entries). Types appear
/// after their first alert.
class AlertTypesSection extends StatefulWidget {
  const AlertTypesSection({super.key, this.prefs = const AlertPrefs()});

  final AlertPrefs prefs;

  @override
  State<AlertTypesSection> createState() => _AlertTypesSectionState();
}

class _AlertTypesSectionState extends State<AlertTypesSection> {
  Map<String, AlertType>? _types;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final types = await widget.prefs.load();
    if (mounted) setState(() => _types = types);
  }

  Future<void> _set(AlertType type, bool on) async {
    await widget.prefs.setMuted(type.ruleId, !on);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final types = _types?.values.toList() ?? const <AlertType>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.alertsSettingsTitle),
        if (types.isEmpty)
          Text(l.alertsSettingsEmpty, style: theme.textTheme.bodySmall)
        else
          for (final t in types)
            SwitchListTile(
              key: ValueKey('alert-type-${t.ruleId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(t.text, style: theme.textTheme.titleSmall),
              subtitle: Text(
                '${t.alertClass == LiveAlertClass.p1 ? l.alertsClassCritical : l.alertsClassWarning}'
                ' · ${t.alertClass == LiveAlertClass.p1 ? l.alertsMuteVoice : l.alertsMuteShow}',
                style: theme.textTheme.bodySmall,
              ),
              value: !t.muted,
              onChanged: (on) => _set(t, on),
            ),
        Padding(
          padding: const EdgeInsets.only(top: Spacing.sm),
          child: Text(l.alertsSettingsHint, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
