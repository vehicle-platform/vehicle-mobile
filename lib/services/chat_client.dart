import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:vehicle_mobile/models/chat_message.dart';
import 'package:vehicle_mobile/services/http_client_factory.dart';
import 'package:vehicle_mobile/services/http_message.dart';
import 'package:vehicle_mobile/services/token_guard.dart';

const Duration chatConnectTimeout = Duration(seconds: 10);

/// A small local model on a Raspberry Pi can take a while to answer.
const Duration chatTotalTimeout = Duration(seconds: 60);

/// Longest message the server accepts (`POST /chat`, 1..500 characters).
const int chatMaxMessageLength = 500;

enum ChatOutcome {
  ok,

  /// 401: the device token is missing or wrong; fix it in the host settings.
  unauthorized,

  /// 422: the server rejected the message.
  invalid,

  /// 429: too many requests; see [ChatResult.retryAfterSeconds].
  rateLimited,

  /// 503 `chat disabled`: the host runs without the assistant.
  disabled,

  /// No answer from the host (network error or timeout).
  unreachable,

  /// Any other failure (other status, malformed body, token refused).
  failed,
}

class ChatResult {
  const ChatResult(this.outcome,
      {this.answer, this.statusCode, this.message, this.retryAfterSeconds});

  final ChatOutcome outcome;
  final ChatAnswer? answer;
  final int? statusCode;

  /// Server detail text for [ChatOutcome.invalid] / [ChatOutcome.failed].
  final String? message;

  /// `Retry-After` of a 429 in seconds, when the server sent a number.
  final int? retryAfterSeconds;

  bool get isSuccess => outcome == ChatOutcome.ok && answer != null;
}

/// Client of vehicle-server's `POST /chat` (D-121 item 1). The [http.Client]
/// is injectable so tests use `package:http/testing.dart`'s `MockClient`.
class ChatClient {
  ChatClient(
      {http.Client? httpClient, Duration totalTimeout = chatTotalTimeout})
      : _httpClient =
            httpClient ?? createHttpClient(connectTimeout: chatConnectTimeout),
        _totalTimeout = totalTimeout;

  final http.Client _httpClient;
  final Duration _totalTimeout;

  Future<ChatResult> send({
    required String baseUrl,
    required String apiToken,
    required String message,
    String? sessionId,
    String locale = 'tr',
  }) async {
    final refusal = tokenSendRefusal(baseUrl);
    if (refusal != null) {
      return ChatResult(ChatOutcome.failed, message: refusal);
    }
    final base = baseUrl.trim();
    final uri = Uri.parse(
        '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}/chat');
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'message': message,
              'session_id': sessionId,
              'locale': locale
            }),
          )
          .timeout(_totalTimeout);
      switch (response.statusCode) {
        case 200:
          try {
            return ChatResult(
              ChatOutcome.ok,
              answer: ChatAnswer.fromJson(
                  jsonDecode(utf8.decode(response.bodyBytes))),
              statusCode: 200,
            );
          } on FormatException catch (error) {
            return ChatResult(ChatOutcome.failed,
                statusCode: 200, message: error.message);
          }
        case 401:
          return ChatResult(ChatOutcome.unauthorized,
              statusCode: 401, message: extractHttpMessage(response));
        case 422:
          return ChatResult(
            ChatOutcome.invalid,
            statusCode: 422,
            message: _validationMessage(response) ?? 'invalid message',
          );
        case 429:
          return ChatResult(
            ChatOutcome.rateLimited,
            statusCode: 429,
            retryAfterSeconds:
                int.tryParse(response.headers['retry-after']?.trim() ?? ''),
          );
        case 503:
          final detail = extractHttpMessage(response);
          if (detail?.trim().toLowerCase() == 'chat disabled') {
            return const ChatResult(ChatOutcome.disabled, statusCode: 503);
          }
          return ChatResult(ChatOutcome.failed,
              statusCode: 503, message: detail ?? 'HTTP 503');
        default:
          return ChatResult(
            ChatOutcome.failed,
            statusCode: response.statusCode,
            message:
                extractHttpMessage(response) ?? 'HTTP ${response.statusCode}',
          );
      }
    } on TimeoutException {
      return const ChatResult(ChatOutcome.unreachable, message: 'timed out');
    } catch (error) {
      if (isNetworkError(error)) {
        return ChatResult(ChatOutcome.unreachable, message: '$error');
      }
      return ChatResult(ChatOutcome.failed, message: '$error');
    }
  }

  /// FastAPI 422 bodies carry `detail` as a string or a list of `{msg: ...}`.
  String? _validationMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List) {
          final messages = [
            for (final item in detail)
              if (item is Map && item['msg'] is String) item['msg'] as String,
          ];
          if (messages.isNotEmpty) return messages.join('; ');
        }
      }
    } on FormatException {
      // fall through
    }
    return extractHttpMessage(response);
  }
}
