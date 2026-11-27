import 'package:vehicle_mobile/l10n/app_localizations.dart';

/// Proposed event mark categories (G4-4 / T68).
///
/// Marks never carry GPS position (D-076); the UTC timestamp links them to a
/// ride window on the server.
enum RideMarkKind {
  misfire('misfire'),
  noise('noise'),
  vibration('vibration'),
  warningLight('warning_light'),
  roughRoad('rough_road'),
  traffic('traffic'),
  other('other');

  const RideMarkKind(this.wireName);

  final String wireName;

  /// Four most common mechanical/rider kinds plus `other` for the glove-friendly
  /// quick picker on the live screen.
  static const List<RideMarkKind> quickPickerKinds = [
    RideMarkKind.vibration,
    RideMarkKind.noise,
    RideMarkKind.misfire,
    RideMarkKind.warningLight,
    RideMarkKind.other,
  ];

  static RideMarkKind? fromWire(Object? raw) {
    if (raw is! String) return null;
    for (final kind in values) {
      if (kind.wireName == raw) return kind;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
        RideMarkKind.misfire => l10n.rideMarkKindMisfire,
        RideMarkKind.noise => l10n.rideMarkKindNoise,
        RideMarkKind.vibration => l10n.rideMarkKindVibration,
        RideMarkKind.warningLight => l10n.rideMarkKindWarningLight,
        RideMarkKind.roughRoad => l10n.rideMarkKindRoughRoad,
        RideMarkKind.traffic => l10n.rideMarkKindTraffic,
        RideMarkKind.other => l10n.rideMarkKindOther,
      };
}

/// One rider-tapped event mark (`{id, t_utc, kind, note?}`; no position).
class RideMark {
  const RideMark({
    required this.id,
    required this.tUtcMs,
    required this.kind,
    this.note,
  });

  final String id;
  final int tUtcMs;
  final RideMarkKind kind;
  final String? note;

  DateTime get timestampUtc =>
      DateTime.fromMillisecondsSinceEpoch(tUtcMs, isUtc: true);

  Map<String, Object?> toJson() => {
        'id': id,
        't_utc': tUtcMs,
        'kind': kind.wireName,
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      };

  static RideMark? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final tUtc = raw['t_utc'];
    final kind = RideMarkKind.fromWire(raw['kind']);
    final note = raw['note'];
    if (id is! String || id.isEmpty || tUtc is! int || kind == null) {
      return null;
    }
    return RideMark(
      id: id,
      tUtcMs: tUtc,
      kind: kind,
      note: note is String && note.trim().isNotEmpty ? note.trim() : null,
    );
  }
}
