import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:vehicle_mobile/models/app_notification.dart';
import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:vehicle_mobile/services/http_client_factory.dart';
import 'package:vehicle_mobile/services/token_guard.dart';

const Duration notificationsConnectTimeout = Duration(seconds: 10);
const Duration notificationsTotalTimeout = Duration(seconds: 20);

/// Largest `limit` the server accepts.
const int notificationsMaxLimit = 100;

/// The `locale` query value for a UI language code: the server stores texts
/// for `en` and `tr` only, anything else asks for `en` (default, D-125).
String notificationsLocaleParam(String code) =>
    code.toLowerCase() == 'tr' ? 'tr' : 'en';

enum NotificationsOutcome {
  ok,

  /// 401: the session ended; also reported on [AuthEvents].
  unauthorized,

  /// 404: an older server without notifications; the feature is hidden.
  notSupported,

  /// 429, see [NotificationsResult.retryAfterSeconds].
  rateLimited,

  unreachable,
  failed,
}

class NotificationsResult {
  const NotificationsResult(this.outcome,
      {this.items = const [],
      this.latestId,
      this.statusCode,
      this.message,
      this.retryAfterSeconds});

  final NotificationsOutcome outcome;
  final List<AppNotification> items;
  final int? latestId;
  final int? statusCode;
  final String? message;
  final int? retryAfterSeconds;

  bool get isSuccess => outcome == NotificationsOutcome.ok;
}

/// Client of `GET /notifications`, `POST /notifications/{id}/read` and
/// `POST /notifications/read-all` (D-123).
class NotificationsClient {
  NotificationsClient(
      {http.Client? httpClient,
      Duration totalTimeout = notificationsTotalTimeout})
      : _http = httpClient ??
            createHttpClient(connectTimeout: notificationsConnectTimeout),
        _timeout = totalTimeout;

  final http.Client _http;
  final Duration _timeout;

  Future<NotificationsResult> list({
    required String baseUrl,
    required String token,
    int sinceId = 0,
    int limit = notificationsMaxLimit,
    String? locale,
  }) async {
    final clamped = limit.clamp(1, notificationsMaxLimit);
    // [locale] is the UI language code; a server without the parameter
    // ignores it. Omitted for callers without a UI (none today).
    final localeQuery =
        locale == null ? '' : '&locale=${notificationsLocaleParam(locale)}';
    final result = await _send(
      'GET',
      baseUrl,
      '/notifications?since_id=$sinceId&limit=$clamped$localeQuery',
      token,
      okStatus: 200,
    );
    return result;
  }

  Future<NotificationsResult> markRead(
          {required String baseUrl, required String token, required int id}) =>
      _send('POST', baseUrl, '/notifications/$id/read', token, okStatus: 204);

  Future<NotificationsResult> markAllRead(
          {required String baseUrl, required String token}) =>
      _send('POST', baseUrl, '/notifications/read-all', token, okStatus: 204);

  Future<NotificationsResult> _send(
      String method, String baseUrl, String path, String token,
      {required int okStatus}) async {
    final refusal = tokenSendRefusal(baseUrl);
    if (refusal != null) {
      return NotificationsResult(NotificationsOutcome.failed, message: refusal);
    }
    final base = baseUrl.trim();
    final uri = Uri.parse(
        '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    try {
      final request = method == 'GET'
          ? _http.get(uri, headers: headers)
          : _http.post(uri, headers: headers);
      final response = await request.timeout(_timeout);
      final status = response.statusCode;
      if (status == okStatus) {
        if (okStatus == 204) {
          return const NotificationsResult(NotificationsOutcome.ok,
              statusCode: 204);
        }
        try {
          final json = jsonDecode(utf8.decode(response.bodyBytes));
          if (json is! Map || json['notifications'] is! List) {
            return const NotificationsResult(NotificationsOutcome.failed,
                statusCode: 200, message: 'malformed response');
          }
          return NotificationsResult(
            NotificationsOutcome.ok,
            statusCode: 200,
            items: [
              for (final item in json['notifications'] as List)
                if (AppNotification.tryFromJson(item) case final n?) n,
            ],
            latestId:
                json['latest_id'] is int ? json['latest_id'] as int : null,
          );
        } on FormatException catch (error) {
          return NotificationsResult(NotificationsOutcome.failed,
              statusCode: 200, message: error.message);
        }
      }
      switch (status) {
        case 401:
          AuthEvents.reportUnauthorized();
          return const NotificationsResult(NotificationsOutcome.unauthorized,
              statusCode: 401);
        case 404:
          return const NotificationsResult(NotificationsOutcome.notSupported,
              statusCode: 404);
        case 429:
          return NotificationsResult(NotificationsOutcome.rateLimited,
              statusCode: 429,
              retryAfterSeconds:
                  int.tryParse(response.headers['retry-after']?.trim() ?? ''));
        default:
          return NotificationsResult(NotificationsOutcome.failed,
              statusCode: status, message: 'HTTP $status');
      }
    } on TimeoutException {
      return const NotificationsResult(NotificationsOutcome.unreachable,
          message: 'timed out');
    } catch (error) {
      if (isNetworkError(error)) {
        return NotificationsResult(NotificationsOutcome.unreachable,
            message: '$error');
      }
      return NotificationsResult(NotificationsOutcome.failed,
          message: '$error');
    }
  }
}
