import 'package:vehicle_mobile/services/app_settings.dart';

/// Why the bearer token must not be sent to [baseUrl], or `null` when it may.
///
/// `https://` is always allowed. Plain `http://` is allowed only when the
/// host is the phone itself or on its own network: loopback, RFC 1918 / IPv6
/// ULA, link-local or an mDNS `.local` name (the desk setup talks to a laptop
/// over http). Everything else, including an unparsable URL or another
/// scheme, is refused so the token and ride data never cross the internet or
/// a foreign network unencrypted (audit C-2).
///
/// Android's network security config cannot express IP ranges, so this guard
/// is the enforcement point; the manifest only has to permit cleartext at all.
String? tokenSendRefusal(String? baseUrl) {
  final uri = Uri.tryParse(baseUrl?.trim() ?? '');
  if (uri == null || uri.host.isEmpty) return 'the server URL is not valid';
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return null;
  if (scheme == 'http' && isLocalServerUrl(baseUrl)) return null;
  if (scheme == 'http') {
    return 'refusing to send the API token over plain http:// to ${uri.host}; '
        'use https:// or a server on the local network';
  }
  return 'unsupported server URL scheme "$scheme"';
}
