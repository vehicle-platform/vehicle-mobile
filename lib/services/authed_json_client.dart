import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:vehicle_mobile/services/http_client_factory.dart';
import 'package:vehicle_mobile/services/http_message.dart';
import 'package:vehicle_mobile/services/token_guard.dart';

/// Transport result of one [AuthedJsonClient.call]: either a parsed success
/// or a failure the owning client maps to its own outcome enum.
class AuthedResult<T> {
  const AuthedResult.success(this.value, {required this.statusCode})
      : ok = true,
        unreachable = false,
        message = null;

  const AuthedResult.failure({
    this.statusCode,
    this.message,
    this.unreachable = false,
  })  : ok = false,
        value = null;

  /// 2xx status of [AuthedJsonClient.call]'s `okStatuses` and the body parsed.
  final bool ok;

  /// Parsed body; `null` for a call without `parse` (no content).
  final T? value;

  /// HTTP status, or `null` when no response arrived (refused, network, timeout).
  final int? statusCode;

  /// Server detail (`message`/`detail`/`error`) or a short transport reason.
  /// Never contains the request body.
  final String? message;

  /// No answer from the host (network error or timeout).
  final bool unreachable;
}

/// Shared transport of the clients that call vehicle-server with a bearer
/// token and JSON (D-107 follow-up of the conversations work): token guard
/// (no token over plain HTTP to a public host), URL building, timeout,
/// network-error mapping, 200 parsing and `AuthEvents.reportUnauthorized()`
/// on a 401. A client keeps only its own outcome enum and status mapping.
class AuthedJsonClient {
  AuthedJsonClient({
    http.Client? httpClient,
    required Duration connectTimeout,
    required Duration totalTimeout,
  })  : _http = httpClient ?? createHttpClient(connectTimeout: connectTimeout),
        _timeout = totalTimeout;

  final http.Client _http;
  final Duration _timeout;

  /// [parse] returns `null` for a malformed body (reported as a failure with
  /// status 200). Omit it for calls without a body to read (204 deletes).
  Future<AuthedResult<T>> call<T>(
    String method,
    String baseUrl,
    String token,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    T? Function(Object? json)? parse,
    Set<int> okStatuses = const {200},
  }) async {
    final refusal = tokenSendRefusal(baseUrl);
    if (refusal != null) return AuthedResult.failure(message: refusal);
    try {
      final request = http.Request(method, buildUri(baseUrl, path, query))
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          if (body != null) 'Content-Type': 'application/json',
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await _http
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_timeout);
      final status = response.statusCode;
      if (okStatuses.contains(status)) {
        if (parse == null) return AuthedResult.success(null, statusCode: status);
        try {
          final parsed = parse(jsonDecode(utf8.decode(response.bodyBytes)));
          if (parsed == null) {
            return AuthedResult.failure(
                statusCode: status, message: 'malformed response');
          }
          return AuthedResult.success(parsed, statusCode: status);
        } on FormatException catch (error) {
          return AuthedResult.failure(
              statusCode: status, message: error.message);
        }
      }
      if (status == 401) AuthEvents.reportUnauthorized();
      // Only the server's detail, never the request body (it may hold a key).
      return AuthedResult.failure(
          statusCode: status, message: extractHttpMessage(response));
    } on TimeoutException {
      return const AuthedResult.failure(message: 'timed out', unreachable: true);
    } catch (error) {
      if (isNetworkError(error)) {
        return AuthedResult.failure(message: '$error', unreachable: true);
      }
      return const AuthedResult.failure(message: 'request failed');
    }
  }

  /// `<baseUrl><path>` without a doubled slash, plus the query.
  static Uri buildUri(String baseUrl, String path, [Map<String, String>? query]) {
    final trimmed = baseUrl.trim();
    final root = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final parsed = Uri.parse('$root$path');
    return query == null || query.isEmpty
        ? parsed
        : parsed.replace(queryParameters: query);
  }
}
