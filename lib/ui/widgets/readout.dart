import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// One instrument readout (D-130 item 1): a small letter-spaced upper-case
/// label, the value in the semi-condensed face with tabular figures and the
/// unit right next to the value. [color] carries a state (accent, advisory,
/// critical) and defaults to the primary text colour.
class Readout extends StatelessWidget {
  const Readout({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.color,
    this.size = ReadoutSize.medium,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final String? unit;

  /// State colour of the value; null = primary text.
  final Color? color;
  final ReadoutSize size;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final valueColor = color ?? t.textPrimary;
    final valueStyle = numberFace(size.valueSize, FontWeight.w600,
        color: valueColor, height: 1.05);
    final unitStyle = numberFace(size.unitSize, FontWeight.w500,
        color: t.textSecondary, height: 1.05);
    return Semantics(
      container: true,
      label: unit == null ? '$label $value' : '$label $value $unit',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxisAlignment,
          children: [
            Text(upperFor(context, label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: Spacing.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedDefaultTextStyle(
                      style: valueStyle,
                      duration: Motion.standard,
                      curve: Motion.curve,
                      child: Text(value),
                    ),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: Spacing.xs),
                  Text(unit!, style: unitStyle),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Size steps of a [Readout].
enum ReadoutSize {
  small(22, 14),
  medium(32, 16),
  large(56, 22),
  hero(96, 32);

  const ReadoutSize(this.valueSize, this.unitSize);
  final double valueSize;
  final double unitSize;
}
