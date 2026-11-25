import 'package:flutter/material.dart';

import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// Width classes (logical px) shared by every screen. The rule is by WIDTH,
/// never by platform: a phone browser or a narrow desktop window gets the
/// mobile layout.
abstract final class Breakpoints {
  /// Below this: bottom navigation bar, full-width content, 16 px gutters.
  static const double compact = 600;

  /// From this width: list + detail panes and the assistant side panel next
  /// to the rail (D-130 item 2). 600-900 px is the rail with single panes.
  static const double wide = 900;

  /// Above this: navigation rail plus a centred, width-limited column.
  static const double expanded = 1024;

  static bool isWide(double width) => width >= wide;

  static bool isCompact(double width) => width < compact;
  static bool usesRail(double width) => width >= compact;
}

/// Maximum content widths on a wide window.
abstract final class ContentWidth {
  /// The chat column.
  static const double assistant = 720;

  /// Lists and forms.
  static const double list = 960;
}

/// Icon sizes (logical px).
abstract final class IconSizes {
  static const double inline = 18;
  static const double regular = 24;
  static const double empty = 40;
}

/// Type scale reference (the sizes live in the text theme): titleLarge 22 for
/// screen titles, titleMedium 17 for card headings, titleSmall 15 for rows,
/// bodyMedium 14 for text, bodySmall 12.5 for captions, labelSmall 12 for
/// upper-case section labels.
abstract final class TypeScale {
  static const double screenTitle = 22;
  static const double heading = 17;
  static const double row = 15;
  static const double body = 14;
  static const double caption = 12.5;
}

/// Keeps the content in one column: full width (with the 16 px gutter the
/// screen already applies) on a phone, at most [maxWidth] centred on a wide
/// window.
class ContentColumn extends StatelessWidget {
  const ContentColumn(
      {super.key, required this.child, this.maxWidth = ContentWidth.list});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Compact empty state: one icon, one line, optionally example chips or an
/// action. No illustration.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.chips = const [],
    this.onChip,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? hint;
  final List<String> chips;
  final ValueChanged<String>? onChip;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: IconSizes.empty, color: t.accent),
            const SizedBox(height: Spacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: Spacing.xs),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
            ],
            if (chips.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (final c in chips)
                    ActionChip(
                      label: Text(c),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onPressed: onChip == null ? null : () => onChip!(c),
                    ),
                ],
              ),
            ],
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
