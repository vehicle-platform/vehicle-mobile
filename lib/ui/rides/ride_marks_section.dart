import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/l10n/rider_format.dart';
import 'package:vehicle_mobile/models/ride_mark.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';

/// Ride detail section listing marks captured within the ride's time window,
/// with a per-row delete action (G4-4 / T68).
class RideMarksSection extends StatelessWidget {
  const RideMarksSection({
    super.key,
    required this.marks,
    required this.loading,
    this.error,
    this.deletingId,
    required this.onDelete,
  });

  final List<RideMark> marks;
  final bool loading;
  final String? error;
  final String? deletingId;
  final ValueChanged<RideMark> onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (loading) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: Spacing.sm),
          child: LinearProgressIndicator(),
        ),
      );
    }
    if (error != null) {
      return SectionCard(child: Text(error!));
    }
    if (marks.isEmpty) {
      return SectionCard(child: Text(l.logbookMarksEmpty));
    }
    return SectionCard(
      child: Column(
        children: [
          for (var i = 0; i < marks.length; i++) ...[
            if (i > 0) const Divider(height: Spacing.md),
            _MarkRow(
              mark: marks[i],
              deleting: deletingId == marks[i].id,
              onDelete: () => onDelete(marks[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.mark,
    required this.deleting,
    required this.onDelete,
  });

  final RideMark mark;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final timeText = RiderFormat.of(context).dateTime(mark.timestampUtc);
    return Row(
      children: [
        const Icon(Icons.flag_outlined, size: 20),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mark.kind.label(l), style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(timeText, style: theme.textTheme.bodySmall),
              if (mark.note != null) ...[
                const SizedBox(height: 2),
                Text(mark.note!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        IconButton(
          key: ValueKey('delete-mark-${mark.id}'),
          tooltip: l.logbookMarkDeleteTooltip,
          onPressed: deleting ? null : onDelete,
          icon: deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
