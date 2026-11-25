import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';

/// The same cleartext warning the Settings screen shows, for the read-only
/// ride screens that send the same bearer token.
class RideCleartextWarning extends StatelessWidget {
  const RideCleartextWarning(
      {super.key, required this.settings, this.padding = EdgeInsets.zero});

  /// Padding of the shown banner; a hidden warning takes no space.
  static const EdgeInsets screenPadding =
      EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0);

  final AppSettings settings;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (!settings.sendsTokenInCleartext) return const SizedBox.shrink();
    return Padding(
        padding: padding,
        child: InfoBanner(
          icon: Icons.warning_amber_rounded,
          tone: Tone.warn,
          text: context.l10n.logbookCleartextWarning,
        ));
  }
}

/// Centered spinner with a label.
class RideLoading extends StatelessWidget {
  const RideLoading(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: Spacing.md),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Full-height message with an optional action button.
class RideMessage extends StatelessWidget {
  const RideMessage({
    super.key,
    required this.icon,
    required this.message,
    this.tone = Tone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final Tone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: toneColor(context, tone)),
            const SizedBox(height: Spacing.md),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Spacing.lg),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
