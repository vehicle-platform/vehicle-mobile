/// Who wrote a chat message.
enum ChatRole { user, assistant }

/// Where the server's answer text came from (`source` of `POST /chat`).
enum ChatSource {
  llm,
  template,
  unsupported,
  error;

  static ChatSource? parse(Object? value) {
    for (final source in ChatSource.values) {
      if (source.name == value) return source;
    }
    return null;
  }
}

/// The vehicle-mcp tool that computed the numbers of an answer (D-121 item 1,
/// invariant 7): the app shows it next to the numbers and never computes or
/// rephrases a number itself.
class ChatToolCall {
  const ChatToolCall({required this.name, this.arguments = const {}});

  final String name;
  final Map<String, Object?> arguments;

  static ChatToolCall? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    final args = json['arguments'];
    return ChatToolCall(
      name: name,
      arguments: args is Map
          ? {for (final e in args.entries) e.key.toString(): e.value}
          : const {},
    );
  }
}

/// A parsed 200 response of `POST /chat`.
class ChatAnswer {
  const ChatAnswer({
    required this.answer,
    required this.source,
    this.tool,
    this.result,
    this.elapsedMs,
  });

  final String answer;
  final ChatSource source;
  final ChatToolCall? tool;

  /// Tool result as sent (object, array, string or null), shown verbatim.
  final Object? result;
  final int? elapsedMs;

  /// Throws [FormatException] when the body is not a chat answer.
  factory ChatAnswer.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('chat answer is not an object');
    }
    final answer = json['answer'];
    if (answer is! String) {
      throw const FormatException('chat answer has no "answer" text');
    }
    final elapsed = json['elapsed_ms'];
    return ChatAnswer(
      answer: answer,
      source: ChatSource.parse(json['source']) ?? ChatSource.error,
      tool: ChatToolCall.tryFromJson(json['tool']),
      result: json['result'],
      elapsedMs: elapsed is num ? elapsed.toInt() : null,
    );
  }
}

/// One entry of the in-memory conversation. Never persisted: answers may
/// contain ride data.
class ChatMessage {
  const ChatMessage.user(this.text)
      : role = ChatRole.user,
        source = null,
        tool = null,
        result = null,
        elapsedMs = null,
        isFailure = false;

  ChatMessage.fromAnswer(ChatAnswer answer)
      : role = ChatRole.assistant,
        text = answer.answer,
        source = answer.source,
        tool = answer.tool,
        result = answer.result,
        elapsedMs = answer.elapsedMs,
        isFailure = false;

  /// A client-side problem (rate limit, host unreachable, ...), not a server answer.
  const ChatMessage.failure(this.text)
      : role = ChatRole.assistant,
        source = null,
        tool = null,
        result = null,
        elapsedMs = null,
        isFailure = true;

  final ChatRole role;
  final String text;
  final ChatSource? source;
  final ChatToolCall? tool;
  final Object? result;
  final int? elapsedMs;
  final bool isFailure;
}

/// One key/value row of a flattened tool argument or result.
class ChatRow {
  const ChatRow(this.key, this.value);

  final String key;
  final String value;
}

/// Flattens [value] into display rows: nested maps become dotted keys
/// (`a.b`), lists show their first [maxListItems] entries (`a[0]`) after a
/// row with the item count and a "+N more" row. Values are rendered exactly as
/// the server sent them: no rounding, no unit conversion.
List<ChatRow> flattenChatValue(Object? value,
    {String key = '', int maxListItems = 5, int maxRows = 60}) {
  final rows = <ChatRow>[];
  void walk(String path, Object? v) {
    if (rows.length >= maxRows) return;
    if (v is Map) {
      if (v.isEmpty) {
        rows.add(ChatRow(path, '{}'));
        return;
      }
      for (final e in v.entries) {
        walk(path.isEmpty ? '${e.key}' : '$path.${e.key}', e.value);
      }
    } else if (v is List) {
      rows.add(
          ChatRow(path, '${v.length} ${v.length == 1 ? 'item' : 'items'}'));
      for (var i = 0; i < v.length && i < maxListItems; i++) {
        walk('$path[$i]', v[i]);
      }
      if (v.length > maxListItems) {
        rows.add(ChatRow('$path[...]', '+${v.length - maxListItems} more'));
      }
    } else {
      rows.add(ChatRow(path, v == null ? 'null' : '$v'));
    }
  }

  walk(key, value);
  if (rows.length >= maxRows) rows.add(const ChatRow('...', 'truncated'));
  return rows;
}
