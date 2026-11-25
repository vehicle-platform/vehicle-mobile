import 'package:flutter/material.dart';
import 'package:vehicle_defs/vehicle_defs.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/telemetry_data.dart';
import 'package:vehicle_mobile/ui/shell/shell_scope.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/telemetry/telemetry_store.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';

/// Link, packet, CAN and tester health. Read-only; everything comes from the
/// newest BLE telemetry packet and the decoder's counters.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key, required this.store});

  final TelemetryStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The Ride sub-navigation already names this screen: no title here.
      appBar: AppBar(
        toolbarHeight: 48,
        actions: const [HeaderActions()],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
            children: [
              _linkSection(context),
              const SizedBox(height: Spacing.lg),
              _packetSection(context),
              const SizedBox(height: Spacing.lg),
              _canSection(context),
              const SizedBox(height: Spacing.lg),
              _testerSection(context),
            ],
          );
        },
      ),
    );
  }

  String _num(int? v) => v == null ? '--' : '$v';

  Widget _flagRow(BuildContext context, String label, bool? value,
      {required bool badWhenTrue}) {
    final t = context.vehicle;
    if (value == null) return KeyValueRow(label: label, value: '--');
    final bad = value == badWhenTrue;
    return KeyValueRow(
      label: label,
      value: value ? context.l10n.rideYes : context.l10n.rideNo,
      valueColor: bad ? t.error : t.live,
    );
  }

  Widget _linkSection(BuildContext context) {
    final data = store.data;
    final since = store.sinceLastPacket;
    final t = context.vehicle;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.rideDiagLink),
        SectionCard(
          child: Column(
            children: [
              KeyValueRow(
                label: l.rideDiagBle,
                value: store.connected
                    ? l.rideConnected.toLowerCase()
                    : l.rideDisconnected.toLowerCase(),
                valueColor: store.connected ? t.live : t.noData,
              ),
              KeyValueRow(
                  label: l.rideDiagDevice, value: store.deviceName ?? '--'),
              KeyValueRow(
                  label: l.rideDiagAttMtu,
                  value: store.mtu == null ? '--' : '${store.mtu}'),
              KeyValueRow(
                  label: l.rideDiagRequestedMtu,
                  value: '${BleGatt.requestedMtu}'),
              KeyValueRow(
                  label: l.rideDiagPacketVersion,
                  value: store.hasPacket ? '${data.packetVersion}' : '--'),
              KeyValueRow(
                  label: l.rideDiagLastPacket,
                  value: since == null
                      ? '--'
                      : l.rideDiagAgoSuffix(formatAge(since.inMilliseconds))),
              KeyValueRow(
                  label: l.rideDiagDeviceTime,
                  value: data.deviceTimeMs == null
                      ? '--'
                      : '${data.deviceTimeMs} ms'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _packetSection(BuildContext context) {
    final l = context.l10n;
    final received = TelemetryData.receivedCount;
    final lost = TelemetryData.lostCount;
    final total = received + lost;
    final loss =
        total == 0 ? '--' : '${(lost * 100 / total).toStringAsFixed(1)} %';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.rideDiagPackets),
        SectionCard(
          child: Column(
            children: [
              KeyValueRow(label: l.rideDiagReceived, value: '$received'),
              KeyValueRow(label: l.rideDiagLostGaps, value: '$lost'),
              KeyValueRow(label: l.rideDiagLoss, value: loss),
              KeyValueRow(
                label: l.rideDiagRejectedVersion,
                value: '${TelemetryData.versionRejectedCount}',
                valueColor: TelemetryData.versionRejectedCount > 0
                    ? context.vehicle.error
                    : null,
              ),
              KeyValueRow(
                label: l.rideDiagRejectedSize,
                value: '${TelemetryData.sizeRejectedCount}',
                valueColor: TelemetryData.sizeRejectedCount > 0
                    ? context.vehicle.error
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _canSection(BuildContext context) {
    final data = store.data;
    final l = context.l10n;
    final can = canStateStatus(data.canBusState, l);
    final hasCan = data.canBusState != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.rideDiagCanBus),
        SectionCard(
          child: Column(
            children: [
              KeyValueRow(
                  label: l.rideDiagBusState,
                  value: can.text,
                  valueColor: toneColor(context, can.tone)),
              KeyValueRow(
                  label: l.rideDiagTxErrors, value: _num(data.canTxErrorCount)),
              KeyValueRow(
                  label: l.rideDiagRxErrors, value: _num(data.canRxErrorCount)),
              KeyValueRow(
                  label: l.rideDiagBusOffEvents,
                  value: _num(data.canBusOffCount)),
              KeyValueRow(
                  label: l.rideDiagUnansweredDids,
                  value: _num(data.unansweredDidCount)),
              _flagRow(context, l.rideDiagPollerEnabled, data.pollerEnabled,
                  badWhenTrue: false),
              _flagRow(
                  context, l.rideDiagForeignLatched, data.latchedForeignTester,
                  badWhenTrue: true),
              _flagRow(context, l.rideDiagBusOffLatched, data.latchedBusOff,
                  badWhenTrue: true),
              _flagRow(context, l.rideDiagSynthetic, data.syntheticData,
                  badWhenTrue: true),
              if (!hasCan)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: Text(
                    l.rideDiagCanNeeds('${TelemetryVersion.v3}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _testerSection(BuildContext context) {
    final l = context.l10n;
    final data = store.data;
    final hasTester = data.stepGapMaxMs != null;
    final count = data.rttCount;
    final sum = data.rttSumMs;
    final avg = (count != null && count > 0 && sum != null)
        ? '${(sum / count).toStringAsFixed(1)} ms'
        : '--';

    String didText = '--';
    final did = data.rttDid;
    if (did != null) {
      final match = vehicleSignalCatalog.where((s) => s.did == did);
      didText =
          match.isEmpty ? didHex(did) : '${match.first.label} (${didHex(did)})';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.rideDiagTester),
        SectionCard(
          child: Column(
            children: [
              KeyValueRow(
                  label: l.rideDiagStepGapMax,
                  value: formatMs(data.stepGapMaxMs)),
              KeyValueRow(
                label: l.rideDiagStepGapOver,
                value: _num(data.stepGapOverCount),
                valueColor: (data.stepGapOverCount ?? 0) > 0
                    ? context.vehicle.stale
                    : null,
              ),
              const Divider(),
              const SizedBox(height: Spacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(upperFor(context, l.rideDiagRoundTrip),
                    style: Theme.of(context).textTheme.labelSmall),
              ),
              KeyValueRow(label: l.rideDiagDid, value: didText),
              KeyValueRow(label: l.rideDiagMin, value: formatMs(data.rttMinMs)),
              KeyValueRow(label: l.rideDiagMax, value: formatMs(data.rttMaxMs)),
              KeyValueRow(label: l.rideDiagMean, value: avg),
              KeyValueRow(label: l.rideDiagSamples, value: _num(data.rttCount)),
              KeyValueRow(
                  label: l.rideDiagNrc78, value: _num(data.rttNrc78Count)),
              if (!hasTester)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: Text(
                    l.rideDiagTesterNeeds('${TelemetryVersion.v4}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
