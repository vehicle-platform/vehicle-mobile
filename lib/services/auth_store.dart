import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/models/account.dart';
import 'package:vehicle_mobile/models/host.dart';
import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/services/host_store.dart';

/// The signed-in account of one host (D-122): the session token lives in the
/// keystore under the host's existing token key (`HostStore.tokenKey`), the
/// username and the vehicle list in shared_preferences (neither is a secret).
class AccountInfo {
  const AccountInfo({required this.username, required this.vehicles});

  final String username;
  final List<AccountVehicle> vehicles;
}

class AuthStore {
  const AuthStore(this.hosts);

  final HostStore hosts;

  static String _key(String hostId) => 'auth.$hostId.account';

  /// Makes [baseUrl] a host (reusing one with the same URL, else adding it)
  /// and returns it. The chosen host moves to the front of the list so the
  /// resolver picks it.
  Future<Host> ensureHost(String baseUrl) async {
    final url = _normalize(baseUrl);
    final list = [...await hosts.load()];
    final index = list.indexWhere((h) => _normalize(h.baseUrl) == url);
    final Host host;
    if (index >= 0) {
      host = list.removeAt(index);
    } else {
      final uri = Uri.tryParse(url);
      host = Host(id: newHostId(), name: uri?.host ?? url, baseUrl: url);
    }
    await hosts.saveHosts([host, ...list]);
    HostResolver.invalidate();
    return host;
  }

  /// Stores a login/registration result for [hostId].
  Future<void> saveSession(String hostId, AuthSession session) async {
    await hosts.writeToken(hostId, session.token);
    await saveAccount(hostId,
        AccountInfo(username: session.username, vehicles: session.vehicles));
    AuthEvents.emit(AuthEvent.signedIn);
  }

  /// Stores a manually entered device token (the "advanced" path); no account.
  Future<void> saveDeviceToken(String hostId, String token) async {
    await hosts.writeToken(hostId, token);
    await clearAccount(hostId);
    AuthEvents.emit(AuthEvent.signedIn);
  }

  Future<void> saveAccount(String hostId, AccountInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key(hostId),
        jsonEncode({
          'username': info.username,
          'vehicles': [for (final v in info.vehicles) v.toJson()],
        }));
  }

  Future<AccountInfo?> readAccount(String hostId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(hostId));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['username'] is! String) return null;
      return AccountInfo(
          username: json['username'] as String,
          vehicles: AccountVehicle.listFromJson(json['vehicles']));
    } on FormatException {
      return null;
    }
  }

  Future<void> clearAccount(String hostId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(hostId));
  }

  /// Forgets the session of [hostId] (logout or a 401): token and account.
  Future<void> clearSession(String hostId,
      {AuthEvent? event = AuthEvent.signedOut}) async {
    await hosts.writeToken(hostId, null);
    await clearAccount(hostId);
    if (event != null) AuthEvents.emit(event);
  }

  static String _normalize(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
