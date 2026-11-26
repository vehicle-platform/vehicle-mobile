import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/models/live_alert.dart';

/// One alert type (a rule of vehicle-defs) the rider has seen.
class AlertType {
  const AlertType({
    required this.ruleId,
    required this.alertClass,
    required this.text,
    required this.muted,
  });

  final String ruleId;
  final LiveAlertClass alertClass;
  final String text;

  /// P1: the voice is muted (the banner always shows, D-129 item 5). P2: the
  /// banner and the voice are muted (the inbox keeps the entry).
  final bool muted;

  AlertType copyWith({bool? muted, String? text}) => AlertType(
      ruleId: ruleId,
      alertClass: alertClass,
      text: text ?? this.text,
      muted: muted ?? this.muted);
}

/// Per-type mutes (D-129 item 5), remembered per rule id as alerts arrive.
/// A P1 type can only be muted from voice to banner, never fully: the
/// controller always shows the banner of a P1 alert whatever this says.
class AlertPrefs {
  const AlertPrefs();

  static const String key = 'settings.alert_types';

  Future<Map<String, AlertType>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    final out = <String, AlertType>{};
    if (raw == null) return out;
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        for (final e in json.entries) {
          final v = e.value;
          if (v is! Map) continue;
          final cls =
              v['class'] == 'P1' ? LiveAlertClass.p1 : LiveAlertClass.p2;
          out['${e.key}'] = AlertType(
            ruleId: '${e.key}',
            alertClass: cls,
            text: v['text'] is String ? v['text'] as String : '${e.key}',
            muted: v['muted'] == true,
          );
        }
      }
    } catch (_) {
      // A damaged value reads as "nothing remembered".
    }
    return out;
  }

  Future<void> _save(Map<String, AlertType> types) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        for (final t in types.values)
          t.ruleId: {
            'class': t.alertClass == LiveAlertClass.p1 ? 'P1' : 'P2',
            'text': t.text,
            'muted': t.muted,
          },
      }),
    );
  }

  /// Remembers the type of [alert] (so Settings can list it) and returns the
  /// stored types.
  Future<Map<String, AlertType>> remember(LiveAlert alert) async {
    final types = await load();
    final known = types[alert.ruleId];
    final next = AlertType(
      ruleId: alert.ruleId,
      alertClass: alert.alertClass,
      text: alert.text.isEmpty ? alert.ruleId : alert.text,
      muted: known?.muted ?? false,
    );
    if (known == null || known.text != next.text) {
      types[alert.ruleId] = next;
      await _save(types);
    }
    return types;
  }

  Future<void> setMuted(String ruleId, bool muted) async {
    final types = await load();
    final t = types[ruleId];
    if (t == null) return;
    types[ruleId] = t.copyWith(muted: muted);
    await _save(types);
  }
}
