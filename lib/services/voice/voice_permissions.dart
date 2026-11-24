import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android 12+: routing audio to a Bluetooth headset needs the runtime
/// BLUETOOTH_CONNECT permission. A denial is not an error: the phone's own
/// microphone and speaker are used then. The microphone permission itself is
/// requested by the speech plugin.
Future<void> requestBluetoothConnectIfNeeded() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Permission.bluetoothConnect.request();
  } catch (_) {
    // Treated as denied.
  }
}
