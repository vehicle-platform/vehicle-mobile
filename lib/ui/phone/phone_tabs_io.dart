import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:vehicle_mobile/services/ble_service.dart';
import 'package:vehicle_mobile/ui/diagnostics_screen.dart';
import 'package:vehicle_mobile/ui/live_screen.dart';
import 'package:vehicle_mobile/ui/phone/phone_tabs.dart';
import 'package:vehicle_mobile/ui/record_screen.dart';
import 'package:vehicle_mobile/ui/signals_screen.dart';
import 'package:vehicle_mobile/ui/telemetry/telemetry_store.dart';

/// Phone tabs only on Android and iOS; desktop builds (macOS) return null and
/// show the computer layout (Assistant, Rides, Faults, Settings).
PhoneTabs? createPhoneTabs() {
  final platform = defaultTargetPlatform;
  if (kIsWeb ||
      (platform != TargetPlatform.android && platform != TargetPlatform.iOS)) {
    return null;
  }
  return IoPhoneTabs();
}

/// The real phone destinations. One BLE connection is shared by every screen,
/// so recording captures the same live connection Live and Signals show.
class IoPhoneTabs implements PhoneTabs {
  IoPhoneTabs({BleService? bleService, TelemetryStore? store})
      : bleService = bleService ?? BleService(),
        _ownsStore = store == null {
    _store = store ?? (TelemetryStore()..attach(this.bleService));
  }

  final BleService bleService;
  final bool _ownsStore;
  late final TelemetryStore _store;

  @override
  Widget live({required VoidCallback onOpenRecord}) => LiveScreen(
      store: _store, bleService: bleService, onOpenRecord: onOpenRecord);

  @override
  Widget signals() => SignalsScreen(store: _store);

  @override
  Widget record({required ValueListenable<int> settingsChanged}) =>
      RecordScreen(
        bleService: bleService,
        initiallyConnected: _store.connected,
        settingsChanged: settingsChanged,
      );

  @override
  Widget diagnostics() => DiagnosticsScreen(store: _store);

  @override
  void dispose() {
    if (_ownsStore) _store.dispose();
  }
}
