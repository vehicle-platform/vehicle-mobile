import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/telemetry/signal_view.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// Colour of a signal state (tokens only).
Color stateColor(BuildContext context, SignalState state) {
  final t = context.vehicle;
  return switch (state) {
    SignalState.live => t.live,
    SignalState.stale => t.stale,
    SignalState.noData => t.noData,
    SignalState.notPolled => t.notPolled,
    SignalState.skipped => t.noData,
    SignalState.negativeResponse => t.error,
  };
}

/// Short upper-case label of a signal state. State is always conveyed by
/// text and icon as well as colour. A negative response shows its NRC
/// (`NRC 0x31`) when [nrc] is known.
String stateLabel(AppLocalizations l, SignalState state, {int? nrc}) =>
    switch (state) {
      SignalState.live => l.settingsSignalLive,
      SignalState.stale => l.settingsSignalStale,
      SignalState.noData => l.settingsSignalNoData,
      SignalState.notPolled => l.settingsSignalNotPolled,
      SignalState.skipped => l.settingsSignalSkipped,
      SignalState.negativeResponse =>
        nrc == null ? 'NRC' : 'NRC ${nrcHex(nrc)}',
    };

IconData stateIcon(SignalState state) => switch (state) {
      SignalState.live => Icons.circle,
      SignalState.stale => Icons.schedule,
      SignalState.noData => Icons.remove_circle_outline,
      SignalState.notPolled => Icons.do_not_disturb_on_outlined,
      SignalState.skipped => Icons.block,
      SignalState.negativeResponse => Icons.error_outline,
    };

/// Upper-case caption above a block of content.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(upperFor(context, text),
                style: Theme.of(context).textTheme.labelSmall),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A flat section (D-130 item 1): content between hairline rules, no fill and
/// no rounded card. [borderColor] switches the rule to a state colour.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: borderColor ?? t.hairline),
          bottom: BorderSide(color: borderColor ?? t.hairline),
        ),
      ),
      // Transparent Material so ink effects of list tiles / switches inside
      // the card paint above the card background.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

Color toneColor(BuildContext context, Tone tone) {
  final t = context.vehicle;
  return switch (tone) {
    Tone.ok => t.live,
    Tone.warn => t.stale,
    Tone.error => t.error,
    Tone.neutral => t.noData,
    Tone.accent => t.accent,
  };
}

/// Compact status chip: icon + text, tinted by [tone].
class StatusPill extends StatelessWidget {
  const StatusPill(
      {super.key,
      required this.icon,
      required this.label,
      this.tone = Tone.neutral});

  final IconData icon;
  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: Spacing.sm),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium!
                  .copyWith(color: context.vehicle.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width message box (warnings, errors, notes).
class InfoBanner extends StatelessWidget {
  const InfoBanner(
      {super.key,
      required this.icon,
      required this.text,
      this.tone = Tone.warn,
      this.title});

  final IconData icon;
  final String text;
  final String? title;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.vehicle.surface,
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: context.vehicle.hairline),
          right: BorderSide(color: context.vehicle.hairline),
          bottom: BorderSide(color: context.vehicle.hairline),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!,
                      style:
                          theme.textTheme.titleSmall!.copyWith(color: color)),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// State chip of a signal: dot/icon + text, never colour alone.
class StateChip extends StatelessWidget {
  const StateChip(this.state, {super.key, this.nrc});

  final SignalState state;

  /// The negative response code shown by [SignalState.negativeResponse].
  final int? nrc;

  @override
  Widget build(BuildContext context) {
    final color = stateColor(context, state);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stateIcon(state),
              size: state == SignalState.live ? 10 : 14, color: color),
          const SizedBox(width: Spacing.xs + 2),
          Text(
            stateLabel(context.l10n, state, nrc: nrc),
            style: Theme.of(context)
                .textTheme
                .labelSmall!
                .copyWith(color: color, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

/// Label on the left, value on the right; wraps instead of overflowing.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(
      {super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(label,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: context.vehicle.textSecondary)),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              flex: 6,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall!.copyWith(color: valueColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
