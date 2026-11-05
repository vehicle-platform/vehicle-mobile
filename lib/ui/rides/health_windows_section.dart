import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/health_windows.dart';
import '../../models/ride_summary.dart';
import '../telemetry/link_status.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'ride_format.dart';

/// The ride-summary health-window section; it renders only what the report block holds.
class HealthWindowsSection extends StatelessWidget {
  const HealthWindowsSection({
    super.key,
    required this.result,
    required this.loading,
    required this.summary,
  });

  final HealthWindowsResult? result;
  final bool loading;
  final RideSummary summary;

  static const String missingReportMessage =
      'No window instances in this report (older server, or run `vehicle-server derive <id>` on the server).';

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SectionCard(
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: Spacing.md),
            Text('Loading window instances...'),
          ],
        ),
      );
    }
    final parsed = result;
    if (parsed == null) return const SizedBox.shrink();
    if (!parsed.isOk) {
      final reason = parsed.reason;
      return SectionCard(
        child: Text(reason == 'not in report'
            ? missingReportMessage
            : reason ?? 'Unavailable.'),
      );
    }
    return _block(context, parsed.block!);
  }

  Widget _block(BuildContext context, HealthWindows block) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(
            icon: Icons.science_outlined,
            label: block.rule,
            tone: Tone.warn,
          ),
          for (var index = 0; index < block.windows.length; index++) ...[
            if (index > 0)
              Divider(height: Spacing.xl, color: context.vehicle.outline),
            _window(context, theme, block.windows[index]),
          ],
          if (block.windows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.md),
              child: Text('No window instances stored.',
                  style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _window(
      BuildContext context, ThemeData theme, HealthWindowInstances window) {
    final signals = _signalsForWindow(summary, window.key);
    final lastEndMs = window.instances.isEmpty
        ? 0
        : window.instances.map((instance) => instance.endMs).reduce(math.max);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(window.key, style: theme.textTheme.titleSmall),
              Text(
                '${window.instances.length} instances, ${window.qualifyingCount} qualifying',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          if (window.instances.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            SizedBox(
              width: double.infinity,
              height: 18,
              child: CustomPaint(
                key: ValueKey('health-window-timeline-${window.key}'),
                painter: WindowTimelinePainter(
                  instances: window.instances,
                  trackColor: context.vehicle.surfaceRaised,
                  outlineColor: context.vehicle.outline,
                  qualifyingColor: context.vehicle.accent,
                  markerColor: context.vehicle.stale,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0 s', style: theme.textTheme.bodySmall),
                Text(
                  formatDurationS(lastEndMs / 1000),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            _table(context, theme, window),
          ],
          if (signals.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            Text('Signals', style: theme.textTheme.labelMedium),
            for (final signal in signals) _signalRow(theme, signal),
          ],
        ],
      ),
    );
  }

  Widget _table(
      BuildContext context, ThemeData theme, HealthWindowInstances window) {
    Widget cell(String text) => Padding(
          padding: const EdgeInsets.only(right: Spacing.md, bottom: Spacing.xs),
          child: Text(text, style: theme.textTheme.bodySmall),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          TableRow(
            children: [
              for (final header in const [
                'Start',
                'End',
                'Duration',
                'Close reason',
                'Qualifies',
                'First'
              ])
                Padding(
                  padding: const EdgeInsets.only(
                      right: Spacing.md, bottom: Spacing.xs),
                  child: Text(header, style: theme.textTheme.labelSmall),
                ),
            ],
          ),
          for (final instance in window.instances)
            TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.vehicle.outline)),
              ),
              children: [
                cell(formatDurationS(instance.startMs / 1000)),
                cell(formatDurationS(instance.endMs / 1000)),
                cell(formatDurationS(instance.durationMs / 1000)),
                cell(instance.closeReason),
                cell(instance.qualifies ? 'yes' : 'no'),
                cell(instance.firstQualifying ? 'first' : ''),
              ],
            ),
        ],
      ),
    );
  }

  Widget _signalRow(ThemeData theme, RideSummarySignal signal) {
    final detail = switch (signal) {
      ScalarSummary() =>
        '${formatRideRangeValue(signal.value, signal.range)} ${signal.unit}',
      _ => signal.status,
    };
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(signal.name, style: theme.textTheme.bodySmall)),
          Text(detail, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

List<RideSummarySignal> _signalsForWindow(
    RideSummary summary, String windowKey) {
  return summary.signals
      .where((signal) =>
          signal.name.startsWith('window_') &&
          summary.signalWindowKeys[signal.name] == windowKey)
      .toList(growable: false);
}

/// Draws one thin segment per instance on a 0..last-end axis; qualifying segments are filled
/// and the first qualifying instance has a marker at its start.
class WindowTimelinePainter extends CustomPainter {
  const WindowTimelinePainter({
    required this.instances,
    required this.trackColor,
    required this.outlineColor,
    required this.qualifyingColor,
    required this.markerColor,
  });

  final List<HealthWindowInstance> instances;
  final Color trackColor;
  final Color outlineColor;
  final Color qualifyingColor;
  final Color markerColor;

  int? get firstQualifyingIndex {
    final index = instances.indexWhere((instance) => instance.firstQualifying);
    return index < 0 ? null : index;
  }

  /// The segments [paint] draws on a canvas of [size]: exactly one per instance, in order.
  List<WindowTimelineSegment> segments(Size size) {
    if (instances.isEmpty || size.width <= 0 || size.height <= 0) {
      return const [];
    }
    final lastEndMs =
        instances.map((instance) => instance.endMs).reduce(math.max);
    final axisMs = lastEndMs <= 0 ? 1 : lastEndMs;
    return [
      for (final instance in instances)
        () {
          final left =
              (size.width * instance.startMs / axisMs).clamp(0.0, size.width);
          final right =
              (size.width * instance.endMs / axisMs).clamp(left, size.width);
          return WindowTimelineSegment(
            left: left,
            right: right,
            qualifies: instance.qualifies,
            firstQualifying: instance.firstQualifying,
          );
        }(),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final segments = this.segments(size);
    if (segments.isEmpty) return;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height / 2 - 3, size.width, 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(track, Paint()..color = trackColor);

    for (final segment in segments) {
      final left = segment.left;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height / 2 - 5,
            math.max(segment.right - left, 1.0), 10),
        const Radius.circular(2),
      );
      if (segment.qualifies) {
        canvas.drawRRect(rect, Paint()..color = qualifyingColor);
      } else {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = outlineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      if (segment.firstQualifying) {
        canvas.drawLine(
          Offset(left, 0),
          Offset(left, size.height),
          Paint()
            ..color = markerColor
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant WindowTimelinePainter oldDelegate) {
    return oldDelegate.instances != instances ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.qualifyingColor != qualifyingColor ||
        oldDelegate.markerColor != markerColor;
  }
}

/// One drawn timeline segment (x range in canvas pixels) of a health-window instance.
class WindowTimelineSegment {
  const WindowTimelineSegment({
    required this.left,
    required this.right,
    required this.qualifies,
    required this.firstQualifying,
  });

  final double left;
  final double right;
  final bool qualifies;
  final bool firstQualifying;
}
