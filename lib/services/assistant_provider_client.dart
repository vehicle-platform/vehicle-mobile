import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:vehicle_mobile/models/assistant_provider.dart';
import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:vehicle_mobile/services/http_client_factory.dart';
import 'package:vehicle_mobile/services/http_message.dart';
import 'package:vehicle_mobile/services/token_guard.dart';

const Duration providerConnectTimeout = Duration(seconds: 10);

/// Listing models and the connection test call the provider, which can be slow.
const Duration providerTotalTimeout = Duration(seconds: 30);

enum ProviderOutcome {
  ok,

  /// 401: the session ended (also reported on [AuthEvents]).
  unauthorized,

  /// 400: saving a cloud provider needs the user's consent.
  consentRequired,

  /// 403: the key may only be sent over HTTPS (or set on the Pi by command).
  insecureTransport,

  /// 404: an older server without these routes.
  notSupported,

  /// 422: the server rejected the input.
  invalid,

  /// 502: the provider itself failed (bad key, quota, unreachable).
  providerError,

  /// 503: the server runs with cloud providers disabled.
  cloudDisabled,

  /// No answer from the host.
  unreachable,

  /// Any other failure.
  failed,
}

class ProviderResult<T> {
  const ProviderResult(this.outcome,
      {this.value, this.statusCode, this.message});

  final ProviderOutcome outcome;
  final T? value;
  final int? statusCode;
  final String? message;

  bool get isSuccess => outcome == ProviderOutcome.ok && value != null;
}

/// Client of vehicle-server's `/assistant/*` routes (D-124). The API key is
/// only ever put into the request body of [save]; it is never logged, kept,
/// or echoed into a result message.
class AssistantProviderClient {
  AssistantProviderClient(
      {http.Client? httpClient, Duration totalTimeout = providerTotalTimeout})
      : _http = httpClient ??
            createHttpClient(connectTimeout: providerConnectTimeout),
        _timeout = totalTimeout;

  final http.Client _http;
  final Duration _timeout;

  Future<ProviderResult<List<AssistantProvider>>> providers(
          {required String baseUrl, required String token}) =>
      _call(baseUrl, token, 'GET', '/assistant/providers',
          parse: (json) => json is Map
              ? AssistantProvider.listFromJson(json['providers'])
              : null);

  Future<ProviderResult<AssistantChoice>> current(
          {required String baseUrl, required String token}) =>
      _call(baseUrl, token, 'GET', '/assistant/provider',
          parse: AssistantChoice.tryFromJson);

  /// [apiKey]: `null` keeps the stored key, `''` deletes it. [baseUrlOverride]
  /// is only sent for the `custom` provider.
  Future<ProviderResult<AssistantChoice>> save({
    required String baseUrl,
    required String token,
    required String provider,
    String? model,
    String? providerBaseUrl,
    String? apiKey,
    required bool consentCloud,
    required bool allowPosition,
  }) =>
      _call(baseUrl, token, 'PUT', '/assistant/provider',
          body: {
            'provider': provider,
            if (model != null && model.isNotEmpty) 'model': model,
            if (provider == customProviderId && providerBaseUrl != null)
              'base_url': providerBaseUrl,
            if (apiKey != null) 'api_key': apiKey,
            'consent_cloud': consentCloud,
            'allow_position': allowPosition,
          },
          parse: AssistantChoice.tryFromJson);

  Future<ProviderResult<List<AssistantModel>>> models(
          {required String baseUrl, required String token}) =>
      _call(baseUrl, token, 'GET', '/assistant/models',
          parse: (json) =>
              json is Map ? AssistantModel.listFromJson(json['models']) : null);

  Future<ProviderResult<ProviderTestResult>> test(
          {required String baseUrl, required String token}) =>
      _call(baseUrl, token, 'POST', '/assistant/provider/test', parse: (json) {
        if (json is! Map) return null;
        final latency = json['latency_ms'];
        return ProviderTestResult(
          ok: json['ok'] == true,
          latencyMs: latency is num ? latency.round() : 0,
          detail: json['detail'] is String ? json['detail'] as String : '',
        );
      });

  Future<ProviderResult<T>> _call<T>(
    String baseUrl,
    String token,
    String method,
    String path, {
    Map<String, Object?>? body,
    required T? Function(Object? json) parse,
  }) async {
    final refusal = tokenSendRefusal(baseUrl);
    if (refusal != null) {
      return ProviderResult(ProviderOutcome.failed, message: refusal);
    }
    final base = baseUrl.trim();
    final uri = Uri.parse(
        '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}$path');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    try {
      final Future<http.Response> request = switch (method) {
        'GET' => _http.get(uri, headers: headers),
        'PUT' => _http.put(uri, headers: headers, body: jsonEncode(body)),
        _ => _http.post(uri, headers: headers),
      };
      final response = await request.timeout(_timeout);
      final status = response.statusCode;
      if (status == 200) {
        try {
          final value = parse(jsonDecode(utf8.decode(response.bodyBytes)));
          if (value == null) {
            return const ProviderResult(ProviderOutcome.failed,
                statusCode: 200, message: 'malformed response');
          }
          return ProviderResult(ProviderOutcome.ok,
              value: value, statusCode: 200);
        } on FormatException catch (error) {
          return ProviderResult(ProviderOutcome.failed,
              statusCode: 200, message: error.message);
        }
      }
      // Never echo the request body (it may hold the key); only the detail.
      final message = extractHttpMessage(response);
      ProviderResult<T> r(ProviderOutcome o) =>
          ProviderResult(o, statusCode: status, message: message);
      switch (status) {
        case 400:
          return r(ProviderOutcome.consentRequired);
        case 401:
          AuthEvents.reportUnauthorized();
          return r(ProviderOutcome.unauthorized);
        case 403:
          return r(ProviderOutcome.insecureTransport);
        case 404:
          return const ProviderResult(ProviderOutcome.notSupported,
              statusCode: 404);
        case 422:
          return r(ProviderOutcome.invalid);
        case 502:
          return r(ProviderOutcome.providerError);
        case 503:
          return r(ProviderOutcome.cloudDisabled);
        default:
          return ProviderResult(ProviderOutcome.failed,
              statusCode: status, message: message ?? 'HTTP $status');
      }
    } on TimeoutException {
      return const ProviderResult(ProviderOutcome.unreachable,
          message: 'timed out');
    } catch (error) {
      if (isNetworkError(error)) {
        return ProviderResult(ProviderOutcome.unreachable, message: '$error');
      }
      return const ProviderResult(ProviderOutcome.failed,
          message: 'request failed');
    }
  }
}
