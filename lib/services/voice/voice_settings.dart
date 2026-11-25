import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the app may read answers aloud by default: on for phones, off for
/// web and desktop.
bool defaultReadAnswers() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// "Read answers aloud": read Ride Assistant's answers aloud. Default on for phones,
/// off for web and desktop. Kept in shared_preferences (not a secret).
class VoiceSettings {
  const VoiceSettings();

  static const String keyReadAnswers = 'settings.voice_read_answers';

  Future<bool> readAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyReadAnswers) ?? defaultReadAnswers();
  }

  Future<void> setReadAnswers(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyReadAnswers, value);
  }
}
