/// One rider notification of vehicle-server (D-123). Everything shown comes
/// from the server's own text; the app adds no wording of its own.
enum NotificationKind {
  rideSummary('ride_summary'),
  fault('fault'),
  dataQuality('data_quality'),
  outlook('outlook');

  const NotificationKind(this.wire);
  final String wire;

  static NotificationKind? parse(Object? value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

enum NotificationSeverity {
  info,
  warning,
  critical;

  static NotificationSeverity? parse(Object? value) {
    for (final severity in values) {
      if (severity.name == value) return severity;
    }
    return null;
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.body,
    required this.createdUtc,
    this.vehicleId,
    this.sessionId,
    this.faultId,
    this.read = false,
  });

  final int id;
  final String? vehicleId;
  final NotificationKind kind;
  final NotificationSeverity severity;
  final String title;
  final String body;
  final String? sessionId;
  final String? faultId;
  final String createdUtc;
  final bool read;

  DateTime? get created => DateTime.tryParse(createdUtc)?.toLocal();

  bool get isCritical => severity == NotificationSeverity.critical;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        vehicleId: vehicleId,
        kind: kind,
        severity: severity,
        title: title,
        body: body,
        sessionId: sessionId,
        faultId: faultId,
        createdUtc: createdUtc,
        read: read ?? this.read,
      );

  /// Null for an entry with an unusable id/title so one bad row cannot hide
  /// the others. Unknown kinds/severities degrade to the mildest value.
  static AppNotification? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final title = json['title'];
    if (id is! int || title is! String) return null;
    String? str(String key) {
      final v = json[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    return AppNotification(
      id: id,
      vehicleId: str('vehicle_id'),
      kind: NotificationKind.parse(json['kind']) ?? NotificationKind.outlook,
      severity: NotificationSeverity.parse(json['severity']) ??
          NotificationSeverity.info,
      title: title,
      body: json['body'] is String ? json['body'] as String : '',
      sessionId: str('session_id'),
      faultId: str('fault_id'),
      createdUtc:
          json['created_utc'] is String ? json['created_utc'] as String : '',
      read: json['read'] == true,
    );
  }
}
