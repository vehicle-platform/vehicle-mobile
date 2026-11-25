import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/ui/phone/phone_tabs.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// The phone's Ride destination (D-130 item 2): live data, signals, recording
/// and diagnostics behind one slim sub-navigation. Recording keeps its state
/// once opened (an active recording must survive a switch); the telemetry
/// screens are rebuilt on demand because their state lives in the telemetry
/// store of [PhoneTabs].
enum RideSub { live, signals, record, diagnostics }

class RideDestination extends StatefulWidget {
  const RideDestination({
    super.key,
    required this.phone,
    required this.settingsChanged,
  });

  final PhoneTabs phone;
  final ValueListenable<int> settingsChanged;

  @override
  State<RideDestination> createState() => _RideDestinationState();
}

class _RideDestinationState extends State<RideDestination> {
  RideSub _sub = RideSub.live;
  final Set<RideSub> _visited = {RideSub.live};

  void _select(RideSub sub) => setState(() {
        _sub = sub;
        _visited.add(sub);
      });

  Widget _build(RideSub sub) => switch (sub) {
        RideSub.live =>
          widget.phone.live(onOpenRecord: () => _select(RideSub.record)),
        RideSub.signals => widget.phone.signals(),
        RideSub.record =>
          widget.phone.record(settingsChanged: widget.settingsChanged),
        RideSub.diagnostics => widget.phone.diagnostics(),
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = {
      RideSub.live: l.rideSubLive,
      RideSub.signals: l.rideSubSignals,
      RideSub.record: l.rideSubRecord,
      RideSub.diagnostics: l.rideSubDiagnostics,
    };
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _SubNav(
            selected: _sub,
            labels: labels,
            onSelected: _select,
          ),
          Expanded(
            child: IndexedStack(
              index: _sub.index,
              children: [
                for (final sub in RideSub.values)
                  if (sub == _sub ||
                      (sub == RideSub.record && _visited.contains(sub)))
                    KeyedSubtree(key: ValueKey(sub), child: _build(sub))
                  else
                    const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim text tabs with a 2 px accent underline on the selected one.
class _SubNav extends StatelessWidget {
  const _SubNav(
      {required this.selected, required this.labels, required this.onSelected});

  final RideSub selected;
  final Map<RideSub, String> labels;
  final ValueChanged<RideSub> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final style = Theme.of(context).textTheme.labelSmall!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.background,
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Row(
        children: [
          for (final sub in RideSub.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: sub == selected,
                child: InkWell(
                  onTap: () => onSelected(sub),
                  child: SizedBox(
                    height: Spacing.touchTarget,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          upperFor(context, labels[sub]!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.copyWith(
                              color:
                                  sub == selected ? t.accent : t.textSecondary),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: Motion.standard,
                            curve: Motion.curve,
                            height: 2,
                            color:
                                sub == selected ? t.accent : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
