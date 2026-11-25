import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:vehicle_mobile/models/account.dart';
import 'package:vehicle_mobile/services/http_client_factory.dart';
import 'package:vehicle_mobile/services/http_message.dart';
import 'package:vehicle_mobile/services/token_guard.dart';

const Duration authConnectTimeout = Duration(seconds: 10);
const Duration authTotalTimeout = Duration(seconds: 20);

enum AuthOutcome {
  ok,

  /// 401: wrong username or password (login), or the session ended.
  unauthorized,

  /// 403: unknown vehicle or wrong/used claim code.
  forbidden,

  /// 409: the username is taken.
  conflict,

  /// 422: the server rejected the input (e.g. password too short).
  invalid,

  /// 429: see [AuthResult.retryAfterSeconds].
  rateLimited,

  /// 404: an older server without accounts.
  notSupported,

  /// No answer from the host.
  unreachable,

  /// Any other failure (status, malformed body, URL refused by the guard).
  failed,
}

class AuthResult {
  const AuthResult(this.outcome,
      {this.session,
      this.vehicles,
      this.statusCode,
      this.message,
      this.retryAfterSeconds});

  final AuthOutcome outcome;

  /// Login / register success.
  final AuthSession? session;

  /// `/auth/me` and `/vehicles/claim` success.
  final List<AccountVehicle>? vehicles;
  final int? statusCode;
  final String? message;
  final int? retryAfterSeconds;

  bool get isSuccess => outcome == AuthOutcome.ok;
}

/// Client of vehicle-server's account routes (D-122). Passwords and tokens
/// are only ever sent in request bodies/headers and never logged or echoed
/// into [AuthResult.message].
class AuthClient {
  AuthClient(
      {http.Client? httpClient, Duration totalTimeout = authTotalTimeout})
      : _http =
            httpClient ?? createHttpClient(connectTimeout: authConnectTimeout),
        _timeout = totalTimeout;

  final http.Client _http;
  final Duration _timeout;

  Future<AuthResult> login(
          {required String baseUrl,
          required String username,
          required String password}) =>
      _session(
          baseUrl, '/auth/login', {'username': username, 'password': password});

  Future<AuthResult> register({
    required String baseUrl,
    required String username,
    required String password,
    required String vehicleId,
    required String claimCode,
  }) =>
      _session(baseUrl, '/auth/register', {
        'username': username,
        'password': password,
        'vehicle_id': vehicleId,
        'claim_code': claimCode,
      });

  /// 204 on success.
  Future<AuthResult> logout({required String baseUrl, required String token}) =>
      _call(baseUrl, 'POST', '/auth/logout', token: token, okStatus: 204);

  Future<AuthResult> me({required String baseUrl, required String token}) =>
      _call(baseUrl, 'GET', '/auth/me', token: token, parse: _vehicles);

  Future<AuthResult> claimVehicle({
    required String baseUrl,
    required String token,
    required String vehicleId,
    required String claimCode,
  }) =>
      _call(baseUrl, 'POST', '/vehicles/claim',
          token: token,
          body: {'vehicle_id': vehicleId, 'claim_code': claimCode},
          parse: _vehicles);

  Future<AuthResult> _session(
          String baseUrl, String path, Map<String, Object?> body) =>
      _call(baseUrl, 'POST', path, body: body, parse: (json) {
        final session = AuthSession.tryFromJson(json);
        return session == null
            ? const AuthResult(AuthOutcome.failed,
                message: 'malformed response')
            : AuthResult(AuthOutcome.ok, session: session, statusCode: 200);
      });

  AuthResult _vehicles(Object? json) {
    if (json is! Map) {
      return const AuthResult(AuthOutcome.failed,
          message: 'malformed response');
    }
    return AuthResult(AuthOutcome.ok,
        vehicles: AccountVehicle.listFromJson(json['vehicles']),
        statusCode: 200);
  }

  Future<AuthResult> _call(
    String baseUrl,
    String method,
    String path, {
    String? token,
    Map<String, Object?>? body,
    int okStatus = 200,
    AuthResult Function(Object? json)? parse,
  }) async {
    final refusal = tokenSendRefusal(baseUrl);
    if (refusal != null) {
      return AuthResult(AuthOutcome.failed, message: refusal);
    }
    final base = baseUrl.trim();
    final uri = Uri.parse(
        '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}$path');
    final headers = {
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    try {
      final request = method == 'GET'
          ? _http.get(uri, headers: headers)
          : _http.post(uri,
              headers: headers, body: body == null ? null : jsonEncode(body));
      final response = await request.timeout(_timeout);
      final status = response.statusCode;
      // 200 and 201 both carry the body of a login/registration.
      if (status == okStatus || (okStatus == 200 && status == 201)) {
        if (parse == null) {
          return AuthResult(AuthOutcome.ok, statusCode: status);
        }
        try {
          return parse(jsonDecode(utf8.decode(response.bodyBytes)));
        } on FormatException catch (error) {
          return AuthResult(AuthOutcome.failed,
              statusCode: status, message: error.message);
        }
      }
      final message = extractHttpMessage(response);
      switch (status) {
        case 401:
          return AuthResult(AuthOutcome.unauthorized,
              statusCode: 401, message: message);
        case 403:
          return AuthResult(AuthOutcome.forbidden,
              statusCode: 403, message: message);
        case 404:
          return const AuthResult(AuthOutcome.notSupported, statusCode: 404);
        case 409:
          return AuthResult(AuthOutcome.conflict,
              statusCode: 409, message: message);
        case 422:
          return AuthResult(AuthOutcome.invalid,
              statusCode: 422,
              message: _validation(response) ?? 'invalid input');
        case 429:
          return AuthResult(AuthOutcome.rateLimited,
              statusCode: 429,
              retryAfterSeconds:
                  int.tryParse(response.headers['retry-after']?.trim() ?? ''));
        default:
          return AuthResult(AuthOutcome.failed,
              statusCode: status, message: message ?? 'HTTP $status');
      }
    } on TimeoutException {
      return const AuthResult(AuthOutcome.unreachable, message: 'timed out');
    } catch (error) {
      if (isNetworkError(error)) {
        return AuthResult(AuthOutcome.unreachable, message: '$error');
      }
      return AuthResult(AuthOutcome.failed, message: '$error');
    }
  }

  String? _validation(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List) {
          final msgs = [
            for (final item in detail)
              if (item is Map && item['msg'] is String) item['msg'] as String,
          ];
          if (msgs.isNotEmpty) return msgs.join('; ');
        }
      }
    } on FormatException {
      // fall through
    }
    return null;
  }
}
