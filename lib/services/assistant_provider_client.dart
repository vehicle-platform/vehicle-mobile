import 'package:http/http.dart' as http;

import 'package:vehicle_mobile/models/assistant_provider.dart';
import 'package:vehicle_mobile/services/authed_json_client.dart';

const Duration providerConnectTimeout = Duration(seconds: 10);

/// Listing models and the connection test call the provider, which can be slow.
const Duration providerTotalTimeout = Duration(seconds: 30);

enum ProviderOutcome {
  ok,

  /// 401: the session ended (also reported on `AuthEvents`).
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
      : _api = AuthedJsonClient(
            httpClient: httpClient,
            connectTimeout: providerConnectTimeout,
            totalTimeout: totalTimeout);

  final AuthedJsonClient _api;

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
    final r = await _api.call<T>(method, baseUrl, token, path,
        body: body, parse: parse);
    if (r.ok) {
      return ProviderResult(ProviderOutcome.ok,
          value: r.value, statusCode: r.statusCode);
    }
    final status = r.statusCode;
    if (status == null) {
      return ProviderResult(
          r.unreachable ? ProviderOutcome.unreachable : ProviderOutcome.failed,
          message: r.message);
    }
    ProviderResult<T> failure(ProviderOutcome o) =>
        ProviderResult(o, statusCode: status, message: r.message);
    return switch (status) {
      400 => failure(ProviderOutcome.consentRequired),
      401 => failure(ProviderOutcome.unauthorized),
      403 => failure(ProviderOutcome.insecureTransport),
      404 => const ProviderResult(ProviderOutcome.notSupported,
          statusCode: 404),
      422 => failure(ProviderOutcome.invalid),
      502 => failure(ProviderOutcome.providerError),
      503 => failure(ProviderOutcome.cloudDisabled),
      _ => ProviderResult(ProviderOutcome.failed,
          statusCode: status, message: r.message ?? 'HTTP $status'),
    };
  }
}
