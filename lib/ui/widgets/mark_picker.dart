import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/ride_mark.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// Glove-friendly quick picker for the 4 most common ride event kinds + other.
///
/// Closes itself automatically after [autoCloseAfter] so a rider does not have
/// to hunt for a dismiss button while riding.
Future<RideMarkKind?> showRideMarkPicker(
  BuildContext context, {
  Duration autoCloseAfter = const Duration(seconds: 5),
}) {
  return showModalBottomSheet<RideMarkKind>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RideMarkPickerSheet(autoCloseAfter: autoCloseAfter),
  );
}

class _RideMarkPickerSheet extends StatefulWidget {
  const _RideMarkPickerSheet({required this.autoCloseAfter});

  final Duration autoCloseAfter;

  @override
  State<_RideMarkPickerSheet> createState() => _RideMarkPickerSheetState();
}

class _RideMarkPickerSheetState extends State<_RideMarkPickerSheet> {
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _autoCloseTimer = Timer(widget.autoCloseAfter, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  IconData _iconOf(RideMarkKind kind) => switch (kind) {
        RideMarkKind.vibration => Icons.vibration,
        RideMarkKind.noise => Icons.hearing,
        RideMarkKind.misfire => Icons.bolt,
        RideMarkKind.warningLight => Icons.warning_amber_rounded,
        RideMarkKind.roughRoad => Icons.terrain,
        RideMarkKind.traffic => Icons.traffic,
        RideMarkKind.other => Icons.flag_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.lg, Spacing.lg, Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.rideMarkPickerTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.xs),
            Text(l.rideMarkPickerHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: Spacing.md),
            for (final kind in RideMarkKind.quickPickerKinds) ...[
              FilledButton.tonalIcon(
                key: ValueKey('mark-kind-${kind.wireName}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                ),
                onPressed: () => Navigator.of(context).pop(kind),
                icon: Icon(_iconOf(kind), size: 24),
                label: Text(
                  kind.label(l),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: Spacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
