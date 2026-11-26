import 'package:flutter/foundation.dart';

/// Whether a ride recording is running. The Record screen sets it; the shell
/// keeps the live alert stream open in the background on Android while it is
/// true (D-129 item 4).
class RecordingActivity {
  RecordingActivity._();

  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);
}
