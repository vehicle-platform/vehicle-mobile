import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:vehicle_mobile/models/host.dart';
import 'package:vehicle_mobile/services/host_store.dart';
import 'package:vehicle_mobile/services/http_client_factory.dart';

/// Per-host `GET /health` probe limit (D-121 item 4).
const Duration hostProbeTimeout = Duration(seconds: 2);

/// A host together with its device token (null when none is stored).
class ActiveHost {
  const ActiveHost(this.host, this.token);

  final Host host;
  final String? token;
}

/// Picks the host the app talks to: hosts are tried in list order (local
/// first) with a short `GET /health` probe and the first reachable one wins.
/// The choice is cached for the process; [invalidate] (pull-to-refresh, a
/// failed request) makes the next [resolve] probe again. A single host is used
/// without probing; when none answers, the first host is returned so the
/// caller shows its normal "unreachable" error against a real URL.
class HostResolver {
  HostResolver(this._store,
      {http.Client? client, Duration timeout = hostProbeTimeout})
      : _client = client,
        _timeout = timeout;

  final HostStore _store;
  final http.Client? _client;
  final Duration _timeout;

  static String? _cachedId;
  static String? _cachedFingerprint;

  /// Forgets the cached choice: the next [resolve] probes again.
  static void invalidate() {
    _cachedId = null;
    _cachedFingerprint = null;
  }

  /// The active host, or null when no host is configured.
  Future<ActiveHost?> resolve({bool forceProbe = false}) async {
    final hosts = await _store.load();
    if (hosts.isEmpty) return null;
    if (hosts.length == 1) return _withToken(hosts.first);

    final fingerprint = hosts.map((h) => '${h.id}|${h.baseUrl}').join('\n');
    if (forceProbe) invalidate();
    if (_cachedFingerprint == fingerprint) {
      final cached = hosts.where((h) => h.id == _cachedId);
      if (cached.isNotEmpty) return _withToken(cached.first);
    }

    final client = _client ?? createHttpClient(connectTimeout: _timeout);
    try {
      for (final host in hosts) {
        if (await _reachable(client, host)) {
          _cachedId = host.id;
          _cachedFingerprint = fingerprint;
          return await _withToken(host);
        }
      }
    } finally {
      if (_client == null) client.close();
    }
    return _withToken(hosts.first);
  }

  Future<bool> _reachable(http.Client client, Host host) async {
    final base = host.baseUrl.trim();
    final uri = Uri.tryParse(
        '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}/health');
    if (uri == null || !uri.hasAuthority) return false;
    try {
      final response = await client.get(uri).timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<ActiveHost> _withToken(Host host) async =>
      ActiveHost(host, await _store.readToken(host.id));
}
