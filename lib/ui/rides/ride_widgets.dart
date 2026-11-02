import 'package:flutter/material.dart';

import '../../services/app_settings.dart';
import '../telemetry/link_status.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// The same cleartext warning the Settings screen shows, for the read-only
/// ride screens that send the same bearer token.
class RideCleartextWarning extends StatelessWidget {
  const RideCleartextWarning({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    if (!settings.sendsTokenInCleartext) return const SizedBox.shrink();
    return const InfoBanner(
      icon: Icons.warning_amber_rounded,
      tone: Tone.warn,
      text:
          'Warning: http:// sends the API token and ride data unencrypted. Use it only '
          'on a trusted local network; use https:// for any server reachable from outside.',
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
            Icon(icon, size: 40, color: toneColor(context, tone)),
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
