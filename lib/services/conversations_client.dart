import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:vehicle_mobile/models/conversation.dart';
import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:vehicle_mobile/services/http_client_factory.dart';
import 'package:vehicle_mobile/services/http_message.dart';
import 'package:vehicle_mobile/services/token_guard.dart';

const Duration conversationsConnectTimeout = Duration(seconds: 10);
const Duration conversationsTotalTimeout = Duration(seconds: 20);

enum ConvOutcome {
  ok,
  unauthorized,
  forbidden,
  notFound,
  notSupported,
  invalid,
  conflict,
  unreachable,
  failed,
}

class ConvResult<T> {
  const ConvResult(this.outcome, {this.value, this.statusCode, this.message});

  final ConvOutcome outcome;
  final T? value;
  final int? statusCode;
  final String? message;

  bool get isSuccess => outcome == ConvOutcome.ok;
}

class ConversationPage {
  const ConversationPage({required this.conversations, this.nextBefore});

  final List<ConversationSummary> conversations;
  final String? nextBefore;
}

/// Client of vehicle-server's `/conversations*` and `/assistant/memory*`
/// routes (D-128). User tokens only (operator and device tokens get 403).
class ConversationsClient {
  ConversationsClient({
    http.Client? httpClient,
    Duration totalTimeout = conversationsTotalTimeout,
  })  : _http = httpClient ??
            createHttpClient(connectTimeout: conversationsConnectTimeout),
        _timeout = totalTimeout;

  final http.Client _http;
  final Duration _timeout;

  Future<ConvResult<ConversationPage>> list({
    required String baseUrl,
    required String token,
    int limit = 50,
    String? before,
  }) {
    final query = <String, String>{
      'limit': '$limit',
      if (before != null && before.isNotEmpty) 'before': before,
    };
    return _call(
      baseUrl,
      token,
      'GET',
      '/conversations',
      query: query,
      parse: (json) {
        if (json is! Map) return null;
        return ConversationPage(
          conversations:
              ConversationSummary.listFromJson(json['conversations']),
          nextBefore:
              json['next_before'] is String ? json['next_before'] as String : null,
        );
      },
    );
  }

  Future<ConvResult<ConversationDetail>> get({
    required String baseUrl,
    required String token,
    required String id,
  }) =>
      _call(
        baseUrl,
        token,
        'GET',
        '/conversations/${Uri.encodeComponent(id)}',
        parse: ConversationDetail.tryFromJson,
      );

  Future<ConvResult<ConversationSummary>> rename({
    required String baseUrl,
    required String token,
    required String id,
    required String title,
  }) =>
      _call(
        baseUrl,
        token,
        'PATCH',
        '/conversations/${Uri.encodeComponent(id)}',
        body: {'title': title},
        parse: ConversationSummary.tryFromJson,
      );

  Future<ConvResult<void>> deleteOne({
    required String baseUrl,
    required String token,
    required String id,
  }) =>
      _callNoContent(
          baseUrl, token, 'DELETE', '/conversations/${Uri.encodeComponent(id)}');

  Future<ConvResult<int>> deleteAll({
    required String baseUrl,
    required String token,
  }) =>
      _call(
        baseUrl,
        token,
        'DELETE',
        '/conversations',
        parse: (json) =>
            json is Map && json['deleted'] is num ? (json['deleted'] as num).toInt() : 0,
      );

  Future<ConvResult<List<ConversationSearchHit>>> search({
    required String baseUrl,
    required String token,
    required String query,
    int limit = 20,
  }) =>
      _call(
        baseUrl,
        token,
        'GET',
        '/conversations/search',
        query: {'q': query, 'limit': '$limit'},
        parse: (json) => json is Map
            ? ConversationSearchHit.listFromJson(json['hits'])
            : null,
      );

  Future<ConvResult<String>> exportJson({
    required String baseUrl,
    required String token,
  }) =>
      _call(
        baseUrl,
        token,
        'GET',
        '/conversations/export',
        parse: (json) => const JsonEncoder.withIndent('  ').convert(json),
      );

  Future<ConvResult<List<MemoryFact>>> listMemory({
    required String baseUrl,
    required String token,
  }) =>
      _call(
        baseUrl,
        token,
        'GET',
        '/assistant/memory',
        parse: (json) =>
            json is Map ? MemoryFact.listFromJson(json['facts']) : null,
      );

  Future<ConvResult<MemoryFact>> putMemory({
    required String baseUrl,
    required String token,
    required String key,
    required String value,
  }) =>
      _call(
        baseUrl,
        token,
        'PUT',
        '/assistant/memory/${Uri.encodeComponent(key)}',
        body: {'value': value},
        parse: MemoryFact.tryFromJson,
      );

  Future<ConvResult<void>> deleteMemory({
    required String baseUrl,
    required String token,
    required String key,
  }) =>
      _callNoContent(
        baseUrl,
        token,
        'DELETE',
        '/assistant/memory/${Uri.encodeComponent(key)}',
      );

  Future<ConvResult<int>> deleteAllMemory({
    required String baseUrl,
    required String token,
  }) =>
      _call(
        baseUrl,
        token,
        'DELETE',
        '/assistant/memory',
        parse: (json) =>
            json is Map && json['deleted'] is num ? (json['deleted'] as num).toInt() : 0,
      );

  Uri _uri(String baseUrl, String path, [Map<String, String>? query]) {
    final trimmed = baseUrl.trim();
    final root = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final parsed = Uri.parse('$root$path');
    return query == null || query.isEmpty
        ? parsed
        : parsed.replace(queryParameters: query);
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    String token,
    Map<String, Object?>? body,
  ) {
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final req = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    return _http.send(req).then(http.Response.fromStream).timeout(_timeout);
  }

  Future<ConvResult<T>> _call<T>(
    String baseUrl,
    String token,
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    required T? Function(Object? json) parse,
  }) async {
    final refusal = tokenSendRefusal(baseUrl);
    if (refusal != null) return ConvResult(ConvOutcome.failed, message: refusal);
    try {
      final response =
          await _send(method, _uri(baseUrl, path, query), token, body);
      if (response.statusCode == 200) {
        try {
          final parsed = parse(jsonDecode(utf8.decode(response.bodyBytes)));
          if (parsed == null) {
            return const ConvResult(ConvOutcome.failed,
                statusCode: 200, message: 'malformed response');
          }
          return ConvResult(ConvOutcome.ok, value: parsed, statusCode: 200);
        } on FormatException catch (e) {
          return ConvResult(ConvOutcome.failed,
              statusCode: 200, message: e.message);
        }
      }
      return _errorResult<T>(response);
    } on TimeoutException {
      return const ConvResult(ConvOutcome.unreachable, message: 'timed out');
    } catch (error) {
      if (isNetworkError(error)) {
        return ConvResult(ConvOutcome.unreachable, message: '$error');
      }
      return ConvResult(ConvOutcome.failed, message: '$error');
    }
  }

  Future<ConvResult<void>> _callNoContent(
    String baseUrl,
    String token,
    String method,
    String path,
  ) async {
    final refusal = tokenSendRefusal(baseUrl);
    if (refusal != null) return ConvResult(ConvOutcome.failed, message: refusal);
    try {
      final response = await _send(method, _uri(baseUrl, path), token, null);
      if (response.statusCode == 204 || response.statusCode == 200) {
        return ConvResult(ConvOutcome.ok, statusCode: response.statusCode);
      }
      return _errorResult<void>(response);
    } on TimeoutException {
      return const ConvResult(ConvOutcome.unreachable, message: 'timed out');
    } catch (error) {
      if (isNetworkError(error)) {
        return ConvResult(ConvOutcome.unreachable, message: '$error');
      }
      return ConvResult(ConvOutcome.failed, message: '$error');
    }
  }

  ConvResult<T> _errorResult<T>(http.Response response) {
    final detail = extractHttpMessage(response);
    switch (response.statusCode) {
      case 401:
        AuthEvents.reportUnauthorized();
        return ConvResult(ConvOutcome.unauthorized,
            statusCode: 401, message: detail);
      case 403:
        return ConvResult(ConvOutcome.forbidden,
            statusCode: 403, message: detail);
      case 404:
        return ConvResult(ConvOutcome.notFound,
            statusCode: 404, message: detail);
      case 409:
        return ConvResult(ConvOutcome.conflict,
            statusCode: 409, message: detail);
      case 422:
        return ConvResult(ConvOutcome.invalid,
            statusCode: 422, message: detail);
      default:
        return ConvResult(
          ConvOutcome.failed,
          statusCode: response.statusCode,
          message: detail ?? 'HTTP ${response.statusCode}',
        );
    }
  }
}
