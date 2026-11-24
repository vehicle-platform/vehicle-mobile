import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/models/host.dart';
import 'package:vehicle_mobile/services/app_settings.dart';

/// Persists the per-user host list (D-121 item 4): the hosts (id, name, URL)
/// in shared_preferences, and each host's device token in the [SecretStore]
/// under `host.<id>.token`. A token is never kept in shared_preferences and is
/// never logged.
class HostStore {
  const HostStore({this.secrets = const PlatformSecretStore(), this.webOrigin});

  final SecretStore secrets;

  /// Own origin of the web build, used as the default first host when the list
  /// is empty (the server serves the web build at `/app`, same origin). Null
  /// outside the web build; tests set it to exercise that path.
  final String? webOrigin;

  static const String _keyHosts = 'hosts.v1';
  static const String originHostId = 'origin';

  // Single-server settings of builds before the host list: migrated once.
  static const String _legacyKeyUrl = 'settings.server_base_url';
  static const String _legacyKeyToken = 'settings.api_token';
  static const String migratedHostId = 'primary';

  /// Secure-storage key of [hostId]'s device token.
  static String tokenKey(String hostId) => 'host.$hostId.token';

  String? get _origin {
    if (webOrigin != null) return webOrigin;
    if (!kIsWeb) return null;
    final base = Uri.base;
    return base.hasAuthority ? base.origin : null;
  }

  /// The hosts in priority order (local first). On first start the old single
  /// URL/token is moved into the first host transparently. When the list is
  /// empty the web build offers its own origin (not persisted until edited).
  Future<List<Host>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyHosts);
    if (raw == null) {
      final migrated = await _migrateLegacy(prefs);
      if (migrated != null) return [migrated];
    } else {
      final hosts = _decode(raw);
      if (hosts.isNotEmpty) return hosts;
    }
    final origin = _origin;
    if (origin != null) {
      return [Host(id: originHostId, name: 'This server', baseUrl: origin)];
    }
    return const [];
  }

  Future<void> saveHosts(List<Host> hosts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyHosts, jsonEncode([for (final h in hosts) h.toJson()]));
  }

  Future<String?> readToken(String hostId) async {
    final token = await secrets.read(tokenKey(hostId));
    return (token == null || token.isEmpty) ? null : token;
  }

  Future<void> writeToken(String hostId, String? token) async {
    final value = token?.trim() ?? '';
    if (value.isEmpty) {
      await secrets.delete(tokenKey(hostId));
    } else {
      await secrets.write(tokenKey(hostId), value);
    }
  }

  /// Removes the host from the list and its token from the keystore.
  Future<void> deleteHost(String hostId) async {
    final hosts = (await load()).where((h) => h.id != hostId).toList();
    await saveHosts(hosts);
    await secrets.delete(tokenKey(hostId));
  }

  List<Host> _decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [
        for (final item in json)
          if (Host.tryFromJson(item) case final host?) host,
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<Host?> _migrateLegacy(SharedPreferences prefs) async {
    final url = (prefs.getString(_legacyKeyUrl) ?? '').trim();
    if (url.isEmpty) return null;
    // Older builds kept the token in shared_preferences; newer ones in the
    // keystore under the legacy key. Prefer the keystore copy.
    var token = await secrets.read(_legacyKeyToken);
    final plainToken = prefs.getString(_legacyKeyToken);
    if ((token == null || token.isEmpty) &&
        plainToken != null &&
        plainToken.isNotEmpty) {
      token = plainToken;
    }
    // Delete the old copies first (a test double may share one slot for all
    // keys), then write the host's own key.
    await secrets.delete(_legacyKeyToken);
    await prefs.remove(_legacyKeyToken);
    final host = Host(id: migratedHostId, name: 'Server', baseUrl: url);
    if (token != null && token.isNotEmpty) {
      await secrets.write(tokenKey(host.id), token);
    }
    await saveHosts([host]);
    await prefs.remove(_legacyKeyUrl);
    return host;
  }
}
