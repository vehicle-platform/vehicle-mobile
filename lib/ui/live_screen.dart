import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vehicle_defs/vehicle_defs.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/services/ble_service.dart';
import 'package:vehicle_mobile/ui/shell/shell_scope.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/telemetry/signal_view.dart';
import 'package:vehicle_mobile/ui/telemetry/telemetry_store.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';
import 'package:vehicle_mobile/ui/widgets/readout.dart';

/// Live dashboard: hero speed, RPM and throttle, secondary tiles, and a
/// compact status strip showing which links and sources are healthy.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    required this.store,
    required this.bleService,
    required this.onOpenRecord,
  });

  final TelemetryStore store;
  final BleService bleService;

  /// Switches the shell to the Record destination.
  final VoidCallback onOpenRecord;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  /// A scan is running (the scan times out after 15 s in [BleService]).
  bool _connecting = false;
  Timer? _connectTimeout;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
  }

  void _onStore() {
    if (_connecting && widget.store.connected) {
      _connectTimeout?.cancel();
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _connectTimeout?.cancel();
    super.dispose();
  }

  void _connectOrDisconnect() {
    if (widget.store.connected) {
      widget.bleService.disconnect();
      return;
    }
    if (_connecting) return;
    setState(() => _connecting = true);
    _connectTimeout?.cancel();
    _connectTimeout = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() => _connecting = false);
    });
    widget.bleService.connectToBike();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The Ride sub-navigation already names this screen: no title here.
      appBar: AppBar(
        toolbarHeight: 48,
        actions: [
          IconButton(
            tooltip: context.l10n.rideLiveOpenRecord,
            onPressed: widget.onOpenRecord,
            icon:
                Icon(Icons.fiber_manual_record, color: context.vehicle.record),
          ),
          const HeaderActions(),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final snapshot = widget.store.snapshot;
          return LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final main = _mainColumn(context, snapshot);
            final side = _sideColumn(context, snapshot);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: main),
                        const SizedBox(width: Spacing.lg),
                        Expanded(flex: 2, child: side),
                      ],
                    )
                  : Column(children: [
                      main,
                      const SizedBox(height: Spacing.lg),
                      side
                    ]),
            );
          });
        },
      ),
    );
  }

  // ---- main column: warnings, hero, rpm + throttle ----

  Widget _mainColumn(BuildContext context, SignalSnapshot snapshot) {
    final store = widget.store;
    final l = context.l10n;
    final speed = snapshot.byName(VehicleSignalNames.vehicleSpeed);
    final rpm = snapshot.byName(VehicleSignalNames.engineSpeed);
    final throttle = snapshot.byName(VehicleSignalNames.throttlePos);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (store.data.syntheticData == true) ...[
          InfoBanner(
            icon: Icons.science_outlined,
            tone: Tone.error,
            title: l.rideSynthTitle,
            text: l.rideSynthText,
          ),
          const SizedBox(height: Spacing.md),
        ],
        _ConnectionCard(
          store: store,
          connecting: _connecting,
          onPressed: _connectOrDisconnect,
        ),
        const SizedBox(height: Spacing.md),
        if (speed != null) _SignalReadout(view: speed, size: ReadoutSize.hero),
        const SizedBox(height: Spacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rpm != null)
              Expanded(
                  child: _SignalReadout(view: rpm, size: ReadoutSize.large)),
            const SizedBox(width: Spacing.md),
            if (throttle != null)
              Expanded(
                child: _SignalReadout(
                    view: throttle, size: ReadoutSize.large, showBar: true),
              ),
          ],
        ),
      ],
    );
  }

  // ---- side column: coolant, battery, status strip, record ----

  Widget _sideColumn(BuildContext context, SignalSnapshot snapshot) {
    final coolant = snapshot.byName(VehicleSignalNames.coolantTemp);
    final battery = snapshot.byName(VehicleSignalNames.batteryVoltage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coolant != null) Expanded(child: _SignalReadout(view: coolant)),
            const SizedBox(width: Spacing.md),
            if (battery != null) Expanded(child: _SignalReadout(view: battery)),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        SectionLabel(context.l10n.rideStatusLabel),
        _StatusStrip(store: widget.store),
        const SizedBox(height: Spacing.lg),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: context.vehicle.record,
            foregroundColor: context.vehicle.onAccent,
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: widget.onOpenRecord,
          icon: const Icon(Icons.fiber_manual_record),
          label: Text(context.l10n.rideRecordCta),
        ),
      ],
    );
  }
}

/// One live signal as an instrument readout: label, tabular value and unit.
/// The value takes the state colour only when it is not live; a state chip
/// and (optionally) a range bar sit under it.
class _SignalReadout extends StatelessWidget {
  const _SignalReadout(
      {required this.view,
      this.size = ReadoutSize.medium,
      this.showBar = false});

  final SignalView view;
  final ReadoutSize size;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final live = view.isLive;
    final fraction = view.fraction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Readout(
          label: view.label,
          value: view.valueText,
          unit: view.unitText,
          size: size,
          color: live ? null : stateColor(context, view.state),
        ),
        if (showBar) ...[
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.chip),
            child: LinearProgressIndicator(
              value: fraction ?? 0,
              minHeight: 4,
              backgroundColor: t.surfaceRaised,
              color: t.accent,
            ),
          ),
        ],
        if (!live) ...[
          const SizedBox(height: Spacing.sm),
          StateChip(view.state, nrc: view.nrc),
        ],
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard(
      {required this.store, required this.connecting, required this.onPressed});

  final TelemetryStore store;
  final bool connecting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    final l = context.l10n;
    final connected = store.connected;
    final since = store.sinceLastPacket;
    final String title;
    final String subtitle;
    if (connected) {
      title = store.deviceName ?? l.rideConnected;
      subtitle = since == null
          ? l.rideWaitingFirstPacket
          : l.rideLastPacketAgoSub(formatAge(since.inMilliseconds));
    } else if (connecting) {
      title = l.rideScanningTitle;
      subtitle = l.rideLookingForBike;
    } else {
      title = l.rideNotConnected;
      subtitle = l.rideTapConnect;
    }
    return SectionCard(
      padding: const EdgeInsets.all(Spacing.md),
      child: Wrap(
        spacing: Spacing.md,
        runSpacing: Spacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: connected ? t.live : t.noData,
                size: 28,
              ),
              const SizedBox(width: Spacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium!
                            .copyWith(color: connected ? t.live : null),
                        overflow: TextOverflow.ellipsis),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          connected
              ? OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.link_off),
                  label: Text(l.rideDisconnect),
                )
              : FilledButton.icon(
                  onPressed: connecting ? null : onPressed,
                  icon: connecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(connecting ? l.rideScanning : l.rideConnect),
                ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.store});

  final TelemetryStore store;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = store.data;
    final live = store.connected && store.hasPacket;
    final pills = <Widget>[];

    pills.add(StatusPill(
      icon: store.connected
          ? Icons.bluetooth_connected
          : Icons.bluetooth_disabled,
      label: store.connected
          ? (store.deviceName == null
              ? l.rideBleConnected
              : l.rideBleDevice(store.deviceName!))
          : l.rideBleDisconnected,
      tone: store.connected ? Tone.ok : Tone.neutral,
    ));

    pills.add(live
        ? StatusPill(
            icon: data.ecuPresent ? Icons.memory : Icons.error_outline,
            label: data.ecuPresent ? l.rideEcuPresent : l.rideEcuNotFound,
            tone: data.ecuPresent ? Tone.ok : Tone.error,
          )
        : StatusPill(icon: Icons.memory, label: l.rideEcuUnknown));

    final can = live
        ? canStateStatus(data.canBusState, l)
        : StatusText(l.rideCanUnknown, Tone.neutral);
    pills.add(StatusPill(
        icon: Icons.settings_ethernet, label: can.text, tone: can.tone));

    if (live && data.pollerEnabled == false) {
      pills.add(StatusPill(
          icon: Icons.pause_circle_outline,
          label: l.ridePollerOff,
          tone: Tone.warn));
    }

    // Latch flags: shown as alarms when set, one calm pill when both clear.
    if (live) {
      final foreign = data.latchedForeignTester;
      final busOff = data.latchedBusOff;
      if (foreign == true) {
        pills.add(StatusPill(
            icon: Icons.lock, label: l.rideForeignLatched, tone: Tone.error));
      }
      if (busOff == true) {
        pills.add(StatusPill(
            icon: Icons.lock, label: l.rideBusOffLatched, tone: Tone.error));
      }
      if (foreign == false && busOff == false) {
        pills.add(StatusPill(
            icon: Icons.lock_open, label: l.rideLatchesClear, tone: Tone.ok));
      }
      if (data.syntheticData == true) {
        pills.add(StatusPill(
            icon: Icons.science_outlined,
            label: l.rideSyntheticData,
            tone: Tone.error));
      }
    }

    pills.add(StatusPill(
      icon: Icons.vibration,
      label: live
          ? (data.imuActive ? l.rideImuActive : l.rideImuInactive)
          : l.rideImuUnknown,
      tone: live ? (data.imuActive ? Tone.ok : Tone.warn) : Tone.neutral,
    ));

    final gps = gpsStatus(store.gpsLink, store.lastGpsBlock, l);
    pills.add(
        StatusPill(icon: Icons.satellite_alt, label: gps.text, tone: gps.tone));

    return Wrap(spacing: Spacing.sm, runSpacing: Spacing.sm, children: pills);
  }
}
