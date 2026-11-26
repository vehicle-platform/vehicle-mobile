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

/// The model that actually answered (`model` of `POST /chat`, D-127 item 1),
/// after any fallback. Absent when a template or the keyword matcher answered
/// and on older servers.
class AnsweringModel {
  const AnsweringModel(
      {required this.providerId, required this.label, this.model});

  final String providerId;
  final String label;
  final String? model;

  /// `label · model`, or just the label when the provider has no model name.
  String get caption {
    final name = model == null ? null : cleanModelName(model!);
    return name == null || name.isEmpty ? label : '$label · $name';
  }

  static AnsweringModel? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['provider_id'];
    final label = json['label'];
    final model = json['model'];
    final hasLabel = label is String && label.isNotEmpty;
    final hasId = id is String && id.isNotEmpty;
    if (!hasLabel && !hasId) return null;
    return AnsweringModel(
      providerId: hasId ? id : '',
      label: hasLabel ? label : id as String,
      model: model is String && model.isNotEmpty ? model : null,
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
    this.model,
    this.chips = const [],
    this.conversationId,
  });

  final String answer;
  final ChatSource source;
  final ChatToolCall? tool;

  /// Tool result as sent (object, array, string or null), shown verbatim.
  final Object? result;
  final int? elapsedMs;

  /// Model that answered; null for a template answer or an older server.
  final AnsweringModel? model;

  /// Follow-up questions offered by the server (`chips`, optional: absent on
  /// older servers). Non-string entries are ignored.
  final List<String> chips;

  /// Stored conversation id returned by the server (D-128); null for temporary
  /// chats or older servers.
  final String? conversationId;

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
    final convId = json['conversation_id'];
    return ChatAnswer(
      answer: answer,
      source: ChatSource.parse(json['source']) ?? ChatSource.error,
      tool: ChatToolCall.tryFromJson(json['tool']),
      result: json['result'],
      elapsedMs: elapsed is num ? elapsed.toInt() : null,
      model: AnsweringModel.tryFromJson(json['model']),
      chips: _parseChips(json['chips']),
      conversationId: convId is String && convId.isNotEmpty ? convId : null,
    );
  }
}

/// Most follow-up chips shown under an answer.
const int chatMaxChips = 6;

List<String> _parseChips(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ].take(chatMaxChips).toList(growable: false);
}

/// Note under an answer that no model phrased (template or unanswered).
enum ChatModelNote { template, unsupported }

/// One entry of the in-memory conversation. Never persisted: answers may
/// contain ride data.
class ChatMessage {
  ChatMessage.user(this.text, {DateTime? at})
      : role = ChatRole.user,
        source = null,
        tool = null,
        result = null,
        elapsedMs = null,
        model = null,
        chips = const [],
        time = at ?? DateTime.now(),
        isFailure = false;

  ChatMessage.fromAnswer(ChatAnswer answer, {DateTime? at})
      : role = ChatRole.assistant,
        text = answer.answer,
        source = answer.source,
        tool = answer.tool,
        result = answer.result,
        elapsedMs = answer.elapsedMs,
        model = answer.model,
        chips = answer.chips,
        time = at ?? DateTime.now(),
        isFailure = false;

  /// A client-side problem (rate limit, host unreachable, ...), not a server answer.
  ChatMessage.failure(this.text, {DateTime? at})
      : role = ChatRole.assistant,
        source = null,
        tool = null,
        result = null,
        elapsedMs = null,
        model = null,
        chips = const [],
        time = at ?? DateTime.now(),
        isFailure = true;

  /// One stored message from `GET /conversations/{id}` (D-128).
  ChatMessage.stored({
    required this.role,
    required this.text,
    this.source,
    this.tool,
    this.result,
    this.elapsedMs,
    this.model,
    DateTime? at,
  })  : chips = const [],
        time = at ?? DateTime.now(),
        isFailure = false;

  final ChatRole role;
  final String text;
  final ChatSource? source;
  final ChatToolCall? tool;
  final Object? result;
  final int? elapsedMs;
  final AnsweringModel? model;
  final List<String> chips;
  final DateTime time;
  final bool isFailure;

  bool get _answered =>
      role == ChatRole.assistant && !isFailure && source != ChatSource.error;

  /// `label · model` of the model that answered; null for the rider's
  /// question, failures, errors, template answers and older servers.
  String? get modelCaption => _answered ? model?.caption : null;

  /// Set when no model phrased the answer.
  ChatModelNote? get modelNote {
    if (!_answered || model != null) return null;
    return switch (source) {
      ChatSource.template => ChatModelNote.template,
      ChatSource.unsupported => ChatModelNote.unsupported,
      _ => null,
    };
  }
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
    {String key = '',
    int maxListItems = 5,
    int maxRows = 60,
    ChatFlattenLabels labels = const ChatFlattenLabels()}) {
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
      rows.add(ChatRow(path, labels.items(v.length)));
      for (var i = 0; i < v.length && i < maxListItems; i++) {
        walk('$path[$i]', v[i]);
      }
      if (v.length > maxListItems) {
        rows.add(ChatRow('$path[...]', labels.more(v.length - maxListItems)));
      }
    } else {
      rows.add(ChatRow(path, v == null ? 'null' : '$v'));
    }
  }

  walk(key, value);
  if (rows.length >= maxRows) rows.add(ChatRow('...', labels.truncated));
  return rows;
}

/// Wording of the synthetic rows of [flattenChatValue] (the UI passes its
/// localized strings; the default is English).
class ChatFlattenLabels {
  const ChatFlattenLabels({
    this.items = _items,
    this.more = _more,
    this.truncated = 'truncated',
  });

  final String Function(int count) items;
  final String Function(int count) more;
  final String truncated;

  static String _items(int n) => '$n ${n == 1 ? 'item' : 'items'}';
  static String _more(int n) => '+$n more';
}

/// A model name for display: a path or a `.gguf` file name shows as its
/// basename without the extension (`/models/qwen2.5-7b-q4.gguf` ->
/// `qwen2.5-7b-q4`); other names stay as they are.
String cleanModelName(String model) {
  var name = model.trim();
  final slash = name.lastIndexOf(RegExp(r'[/\\]'));
  if (slash >= 0) name = name.substring(slash + 1);
  if (name.toLowerCase().endsWith('.gguf')) {
    name = name.substring(0, name.length - 5);
  }
  return name.isEmpty ? model.trim() : name;
}
