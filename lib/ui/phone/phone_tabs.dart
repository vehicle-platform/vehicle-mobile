import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:vehicle_mobile/models/rider_input.dart';

/// The phone-only destinations (live BLE telemetry, signals, recording,
/// diagnostics). Behind this interface so the shell and `main.dart` never
/// import BLE, `dart:io` or path_provider code: the web build compiles only
/// the stub (D-121 item 3), and desktop/web hide these screens.
abstract class PhoneTabs {
  Widget live({required VoidCallback onOpenRecord});
  Widget signals();
  Widget record({required ValueListenable<int> settingsChanged});
  Widget diagnostics();

  /// Handlebar push-to-talk actions (BLE `riderInput`, D-121 item 5); null
  /// where there is no BLE.
  Stream<RiderInputAction>? get riderInputActions;
  void dispose();
}
