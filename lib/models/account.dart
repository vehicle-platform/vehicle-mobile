/// A vehicle linked to the signed-in account (D-122): the platform's
/// `vehicle_id` and the display name the operator gave it. Never a VIN.
class AccountVehicle {
  const AccountVehicle({required this.vehicleId, required this.name});

  final String vehicleId;
  final String name;

  Map<String, Object?> toJson() => {'vehicle_id': vehicleId, 'name': name};

  static AccountVehicle? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['vehicle_id'];
    final name = json['name'];
    if (id is! String || id.isEmpty) return null;
    return AccountVehicle(vehicleId: id, name: name is String ? name : id);
  }

  static List<AccountVehicle> listFromJson(Object? json) => json is List
      ? [
          for (final item in json)
            if (tryFromJson(item) case final v?) v,
        ]
      : const [];

  @override
  bool operator ==(Object other) =>
      other is AccountVehicle &&
      other.vehicleId == vehicleId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(vehicleId, name);
}

/// What the server answers to a login or registration. The [token] goes to
/// the keystore only; [username] and [vehicles] are kept in preferences.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.username,
    required this.vehicles,
    this.expiresUtc,
  });

  final String token;
  final String username;
  final List<AccountVehicle> vehicles;
  final String? expiresUtc;

  /// Null when the body lacks a token or a username.
  static AuthSession? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final token = json['token'];
    final user = json['user'];
    final username = user is Map ? user['username'] : null;
    if (token is! String || token.isEmpty || username is! String) return null;
    final expires = json['expires_utc'];
    return AuthSession(
      token: token,
      username: username,
      vehicles: AccountVehicle.listFromJson(json['vehicles']),
      expiresUtc: expires is String ? expires : null,
    );
  }

  // The token must never reach a log line.
  @override
  String toString() => 'AuthSession($username, ${vehicles.length} vehicles)';
}
