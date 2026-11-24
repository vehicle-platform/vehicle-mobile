/// One vehicle-server the rider can reach (D-121 item 4): for example "Bike
/// (local Raspi)" and "Remote server". The device token of a host is NOT part
/// of this model: it lives in the platform keystore under the host id (see
/// `HostStore`) and is never put in shared_preferences or logged.
class Host {
  const Host({required this.id, required this.name, required this.baseUrl});

  /// Stable key (also the secure-storage key suffix); never shown to the rider.
  final String id;
  final String name;

  /// e.g. `https://vehicle-server.example.com` or `http://192.168.1.20:8000`.
  final String baseUrl;

  Host copyWith({String? name, String? baseUrl}) =>
      Host(id: id, name: name ?? this.name, baseUrl: baseUrl ?? this.baseUrl);

  Map<String, Object?> toJson() =>
      {'id': id, 'name': name, 'base_url': baseUrl};

  /// Returns `null` for a malformed entry so one corrupt record cannot take
  /// the whole list down.
  static Host? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final baseUrl = json['base_url'];
    if (id is! String || id.isEmpty || name is! String || baseUrl is! String) {
      return null;
    }
    return Host(id: id, name: name, baseUrl: baseUrl);
  }

  @override
  bool operator ==(Object other) =>
      other is Host &&
      other.id == id &&
      other.name == name &&
      other.baseUrl == baseUrl;

  @override
  int get hashCode => Object.hash(id, name, baseUrl);

  @override
  String toString() => 'Host($id, $name, $baseUrl)';
}

/// New host id, unique enough for a handful of hosts on one device.
String newHostId() =>
    'h${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
