import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/ui/shell/shell_scope.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/telemetry/signal_view.dart';
import 'package:vehicle_mobile/ui/telemetry/telemetry_store.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';
import 'package:vehicle_mobile/ui/widgets/readout.dart';

enum _Filter { all, polled, candidates }

/// Every signal of the generated catalog, grouped in catalog group order,
/// with its state, age and poll period. This is where the user sees which
/// data actually flows.
class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key, required this.store});

  final TelemetryStore store;

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  _Filter _filter = _Filter.all;

  bool _matches(SignalView v) => switch (_filter) {
        _Filter.all => true,
        _Filter.polled => v.signal.isPolled,
        _Filter.candidates => !v.signal.isPolled,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The Ride sub-navigation already names this screen: no title here.
      appBar: AppBar(
        toolbarHeight: 48,
        actions: const [HeaderActions()],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final snapshot = widget.store.snapshot;
          final items = <Widget>[
            _SummaryCard(snapshot: snapshot),
            const SizedBox(height: Spacing.md),
            _FilterBar(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: Spacing.sm),
          ];
          for (final group in snapshot.groups) {
            final rows = group.signals.where(_matches).toList(growable: false);
            if (rows.isEmpty) continue;
            items.add(_GroupHeader(
                title: group.title,
                live: group.liveCount,
                total: group.signals.length));
            for (final v in rows) {
              items.add(Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: _SignalRow(view: v),
              ));
            }
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
            itemCount: items.length,
            itemBuilder: (context, i) => items[i],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.snapshot});

  final SignalSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final l = context.l10n;
    return SectionCard(
      child: Row(
        children: [
          Expanded(
              child: Readout(
                  label: l.rideSigLive,
                  value: '${snapshot.liveCount}',
                  color: t.live,
                  size: ReadoutSize.large)),
          Expanded(
              child: Readout(
                  label: l.rideSigPolled,
                  value: '${snapshot.polledCount}',
                  size: ReadoutSize.large)),
          Expanded(
              child: Readout(
                  label: l.rideSigCandidates,
                  value: '${snapshot.candidateCount}',
                  color: t.textSecondary,
                  size: ReadoutSize.large)),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final _Filter value;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_Filter>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
              value: _Filter.all, label: Text(context.l10n.rideFilterAll)),
          ButtonSegment(
              value: _Filter.polled,
              label: Text(context.l10n.rideFilterPolled)),
          ButtonSegment(
              value: _Filter.candidates,
              label: Text(context.l10n.rideFilterCandidates)),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(
      {required this.title, required this.live, required this.total});

  final String title;
  final int live;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.sm),
      child: SectionLabel(title,
          trailing: Text(context.l10n.rideGroupLive(live, total),
              style: Theme.of(context).textTheme.labelSmall)),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.view});

  final SignalView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    final live = view.isLive;
    final valueColor = live ? t.textPrimary : stateColor(context, view.state);
    final signal = view.signal;
    final l = context.l10n;
    final String detail;
    if (signal.isPolled) {
      final poll = l.ridePollEvery(signal.pollPeriodMs ?? 0);
      detail = view.ageMs == null
          ? poll
          : l.rideAgeDetail(formatAge(view.ageMs), poll);
    } else if (view.state == SignalState.notPolled) {
      detail = l.rideNotPolled;
    } else {
      // A catalog candidate the node reports anyway (promoted in newer
      // firmware): there is no poll period in this app's catalog.
      final reported = l.rideReportedByNode;
      detail = view.ageMs == null
          ? reported
          : l.rideAgeDetail(formatAge(view.ageMs), reported);
    }
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.md),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: live ? t.live : Colors.transparent, width: 2),
          bottom: BorderSide(color: t.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(view.label, style: theme.textTheme.titleMedium),
                    Text(view.didText, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.md),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(view.valueText,
                          style: numberFace(28, FontWeight.w600,
                              color: valueColor)),
                      const SizedBox(width: Spacing.xs),
                      Text(view.unitText,
                          style: numberFace(16, FontWeight.w500,
                              color: t.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StateChip(view.state, nrc: view.nrc),
              Text(detail, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
