import 'package:flutter/material.dart';

import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// D-129 priority class of an in-ride alert: P1 urgent (red), P2 advisory
/// (amber). P0 safety decisions never come through the app (invariant 3).
enum AlertClass { p1, p2 }

/// Full-width in-ride alert banner (D-130 item 4): a class-colour stripe, one
/// short sentence and the value that fired it, readable at a glance. The caller
/// decides how long it shows (it must not cover live readouts for longer than
/// its display time); the inbox keeps the history.
class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.alertClass,
    required this.message,
    this.value,
    this.unit,
    this.onTap,
    this.trailing,
  });

  final AlertClass alertClass;

  /// One sentence.
  final String message;

  /// The value that fired the alert (already formatted), with its [unit].
  final String? value;
  final String? unit;
  final VoidCallback? onTap;
  final Widget? trailing;

  static Color colorOf(VehicleTokens t, AlertClass c) =>
      c == AlertClass.p1 ? t.critical : t.advisory;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final color = colorOf(t, alertClass);
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: [message, if (value != null) '$value ${unit ?? ''}'.trim()]
          .join('. '),
      child: Material(
        color: t.surfaceRaised,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: Spacing.touchTarget + 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: color, width: 6),
                bottom: BorderSide(color: t.hairline),
              ),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(message,
                      style: theme.textTheme.titleSmall!
                          .copyWith(color: t.textPrimary)),
                ),
                if (value != null) ...[
                  const SizedBox(width: Spacing.lg),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(value!,
                          style: numberFace(32, FontWeight.w600,
                              color: color, height: 1.0)),
                      if (unit != null) ...[
                        const SizedBox(width: Spacing.xs),
                        Text(unit!,
                            style: numberFace(16, FontWeight.w500,
                                color: t.textSecondary)),
                      ],
                    ],
                  ),
                ],
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
