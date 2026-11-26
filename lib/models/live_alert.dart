/// D-129 priority class of a live in-ride alert.
enum LiveAlertClass { p1, p2 }

/// One `alert` or `clear` event of `GET /alerts/stream` (D-129, vehicle-server
/// "In-ride alerts"). The text is the rule's fixed text from defs; the value
/// and unit come from the event record. Nothing here is computed by the app.
class LiveAlert {
  const LiveAlert({
    required this.isClear,
    required this.ruleId,
    required this.alertClass,
    required this.severity,
    required this.text,
    required this.detail,
    required this.value,
    required this.unit,
    required this.deviceId,
    required this.ts,
    required this.speak,
    required this.reason,
    this.id,
  });

  /// `clear` event (the alert ended; [reason] says why).
  final bool isClear;

  /// Stored notification id (the inbox entry), null when none was stored.
  final int? id;
  final String ruleId;
  final LiveAlertClass alertClass;
  final String severity;
  final String text;
  final String detail;
  final num? value;
  final String? unit;
  final String? deviceId;
  final DateTime? ts;

  /// Only P1 alerts under the per-ride cap ask to be spoken.
  final bool speak;

  /// null for `alert`; `recovered`, `gate` or `ride_end` for `clear`.
  final String? reason;

  /// Same rule on the same device is one alert.
  String get key => '${deviceId ?? ''}|$ruleId';

  /// Parses the `data` of an SSE event; null for anything malformed (the
  /// stream keeps going).
  static LiveAlert? tryParse(String eventName, Object? json) {
    if (json is! Map) return null;
    final rule = json['rule_id'];
    if (rule is! String || rule.isEmpty) return null;
    final cls = switch (json['class']) {
      'P1' => LiveAlertClass.p1,
      'P2' => LiveAlertClass.p2,
      _ => null,
    };
    if (cls == null) return null;
    final event = json['event'] is String ? json['event'] as String : eventName;
    if (event != 'alert' && event != 'clear') return null;
    final ts = json['ts'] is String ? DateTime.tryParse(json['ts'] as String) : null;
    String str(Object? v) => v is String ? v : '';
    return LiveAlert(
      isClear: event == 'clear',
      id: json['id'] is int ? json['id'] as int : null,
      ruleId: rule,
      alertClass: cls,
      severity: str(json['severity']),
      text: str(json['text']),
      detail: str(json['detail']),
      value: json['value'] is num ? json['value'] as num : null,
      unit: json['unit'] is String && (json['unit'] as String).isNotEmpty
          ? json['unit'] as String
          : null,
      deviceId: json['device_id'] is String ? json['device_id'] as String : null,
      ts: ts,
      speak: json['speak'] == true,
      reason: json['reason'] is String ? json['reason'] as String : null,
    );
  }
}
