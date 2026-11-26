import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:vehicle_mobile/models/conversation.dart';
import 'package:vehicle_mobile/services/authed_json_client.dart';

const Duration conversationsConnectTimeout = Duration(seconds: 10);
const Duration conversationsTotalTimeout = Duration(seconds: 20);

enum ConvOutcome {
  ok,
  unauthorized,
  forbidden,
  notFound,
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

  /// A transient failure worth retrying (no answer, or a server error).
  bool get isTransient =>
      outcome == ConvOutcome.unreachable || outcome == ConvOutcome.failed;
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
  }) : _api = AuthedJsonClient(
            httpClient: httpClient,
            connectTimeout: conversationsConnectTimeout,
            totalTimeout: totalTimeout);

  final AuthedJsonClient _api;

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
      _call<void>(
        baseUrl,
        token,
        'DELETE',
        '/conversations/${Uri.encodeComponent(id)}',
        okStatuses: const {200, 204},
      );

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
      _call<void>(
        baseUrl,
        token,
        'DELETE',
        '/assistant/memory/${Uri.encodeComponent(key)}',
        okStatuses: const {200, 204},
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

  Future<ConvResult<T>> _call<T>(
    String baseUrl,
    String token,
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    T? Function(Object? json)? parse,
    Set<int> okStatuses = const {200},
  }) async {
    final r = await _api.call<T>(method, baseUrl, token, path,
        query: query, body: body, parse: parse, okStatuses: okStatuses);
    return mapAuthedResult(r);
  }

  /// Status mapping of the conversations routes: 401 session ended, 403 the
  /// token kind is not allowed (operator/device), 404 an older server without
  /// the routes (or an unknown id), 409, 422.
  static ConvResult<T> mapAuthedResult<T>(AuthedResult<T> r) {
    if (r.ok) {
      return ConvResult(ConvOutcome.ok,
          value: r.value, statusCode: r.statusCode);
    }
    final status = r.statusCode;
    if (status == null) {
      return ConvResult(
          r.unreachable ? ConvOutcome.unreachable : ConvOutcome.failed,
          message: r.message);
    }
    final outcome = switch (status) {
      401 => ConvOutcome.unauthorized,
      403 => ConvOutcome.forbidden,
      404 => ConvOutcome.notFound,
      409 => ConvOutcome.conflict,
      422 => ConvOutcome.invalid,
      _ => ConvOutcome.failed,
    };
    return ConvResult(outcome,
        statusCode: status,
        message: r.message ??
            (outcome == ConvOutcome.failed ? 'HTTP $status' : null));
  }
}
