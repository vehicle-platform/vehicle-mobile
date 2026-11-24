import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/services/host_store.dart';
import 'package:vehicle_mobile/services/secret_store.dart';

export 'package:vehicle_mobile/services/secret_store.dart';

/// App-wide settings for talking to vehicle-server: where it is, how to
/// authenticate, and whether uploads should wait for Wi-Fi.
///
/// Since D-121 the URL and token are those of the *active host* of the
/// per-user host list (see [HostStore], [HostResolver]); every client that
/// reads [AppSettingsStore.load] therefore follows the active host. The
/// Wi-Fi switch lives in shared_preferences.
class AppSettings {
  const AppSettings({
    this.serverBaseUrl,
    this.apiToken,
    this.uploadOnlyOnWifi = true,
    this.hostId,
    this.hostName,
  });

  /// Id and display name of the active host (null when none is configured).
  final String? hostId;
  final String? hostName;

  /// e.g. `https://vehicle-server.example.com`. `null`/empty means "no server
  /// configured yet" -- uploads are disabled in the UI in that case, but
  /// recording and sharing sessions locally keep working regardless.
  final String? serverBaseUrl;

  final String? apiToken;

  /// Default on: avoid uploading a multi-megabyte session archive over a
  /// mobile data connection without the rider asking for it.
  final bool uploadOnlyOnWifi;

  bool get isServerConfigured =>
      serverBaseUrl != null && serverBaseUrl!.trim().isNotEmpty;

  /// True when the configured URL is plain `http://` to a host other than the
  /// phone itself: the bearer token would cross the network unencrypted. Allowed
  /// (a workshop laptop on the local Wi-Fi is the common case) but warned about.
  bool get sendsTokenInCleartext => isCleartextRemoteUrl(serverBaseUrl);

  AppSettings copyWith({
    String? serverBaseUrl,
    String? apiToken,
    bool? uploadOnlyOnWifi,
  }) =>
      AppSettings(
        serverBaseUrl: serverBaseUrl ?? this.serverBaseUrl,
        apiToken: apiToken ?? this.apiToken,
        uploadOnlyOnWifi: uploadOnlyOnWifi ?? this.uploadOnlyOnWifi,
      );
}

/// True for an `http://` URL whose host is not the phone itself.
bool isCleartextRemoteUrl(String? url) {
  final uri = Uri.tryParse(url?.trim() ?? '');
  if (uri == null || uri.scheme.toLowerCase() != 'http') return false;
  const local = {'localhost', '127.0.0.1', '::1'};
  return !local.contains(uri.host.toLowerCase());
}

/// True when [url]'s host is on the phone's own network: `localhost`, an
/// mDNS `.local` name, or a loopback, private (RFC 1918 / IPv6 ULA) or
/// link-local address. A session with `gps.csv` uploads only to such a host
/// (D-063). Decided from the URL alone: a public name that resolves to a LAN
/// address counts as not local, so the guard can only err towards blocking.
///
/// Pure Dart (no `dart:io`) so it also runs in the web build (D-121).
bool isLocalServerUrl(String? url) {
  final uri = Uri.tryParse(url?.trim() ?? '');
  if (uri == null || uri.host.isEmpty) return false;
  final host = uri.host.toLowerCase();
  if (host == 'localhost' || host.endsWith('.local')) return true;
  final v4 = _parseIPv4(host);
  if (v4 != null) {
    return v4[0] == 127 || // loopback
        (v4[0] == 169 && v4[1] == 254) || // link-local
        v4[0] == 10 ||
        (v4[0] == 172 && (v4[1] & 0xF0) == 16) ||
        (v4[0] == 192 && v4[1] == 168);
  }
  final v6 = _parseIPv6(host);
  if (v6 == null) return false;
  final isLoopback = v6.take(15).every((b) => b == 0) && v6[15] == 1;
  final isLinkLocal = v6[0] == 0xFE && (v6[1] & 0xC0) == 0x80; // fe80::/10
  final isUniqueLocal = (v6[0] & 0xFE) == 0xFC; // fc00::/7
  return isLoopback || isLinkLocal || isUniqueLocal;
}

List<int>? _parseIPv4(String host) {
  try {
    return Uri.parseIPv4Address(host);
  } on FormatException {
    return null;
  }
}

List<int>? _parseIPv6(String host) {
  final zone = host.indexOf('%');
  try {
    return Uri.parseIPv6Address(zone < 0 ? host : host.substring(0, zone));
  } on FormatException {
    return null;
  }
}

/// Reads the app settings: the active host's URL and token (host list, D-121)
/// and the Wi-Fi switch (shared_preferences). Hosts and their tokens are edited
/// through [HostStore]; [save] only writes the upload policy.
class AppSettingsStore {
  const AppSettingsStore({
    this.secrets = const PlatformSecretStore(),
    this.probeClient,
    this.webOrigin,
  });

  final SecretStore secrets;

  /// Client for the `/health` probes; null uses a short-connect-timeout client.
  final http.Client? probeClient;

  /// Own origin of the web build (see [HostStore.webOrigin]); tests only.
  final String? webOrigin;

  static const String _keyUploadOnlyOnWifi = 'settings.upload_only_on_wifi';

  HostStore get hosts => HostStore(secrets: secrets, webOrigin: webOrigin);

  /// Settings of the active host. Uses the cached choice; pass [reprobe] to
  /// probe the hosts again (pull-to-refresh, after a failed request).
  Future<AppSettings> load({bool reprobe = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final active = await HostResolver(hosts, client: probeClient)
        .resolve(forceProbe: reprobe);
    final baseUrl = active?.host.baseUrl.trim() ?? '';
    return AppSettings(
      serverBaseUrl: baseUrl.isEmpty ? null : baseUrl,
      apiToken: active?.token,
      uploadOnlyOnWifi: prefs.getBool(_keyUploadOnlyOnWifi) ?? true,
      hostId: active?.host.id,
      hostName: active?.host.name,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUploadOnlyOnWifi, settings.uploadOnlyOnWifi);
  }
}
