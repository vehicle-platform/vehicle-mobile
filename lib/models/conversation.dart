import 'package:vehicle_mobile/models/chat_message.dart';

/// One row of `GET /conversations` (D-128).
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.created,
    required this.updated,
    this.mode = 'data',
  });

  final String id;
  final String title;
  final String created;
  final String updated;
  final String mode;

  static ConversationSummary? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final title = json['title'];
    if (id is! String || id.isEmpty || title is! String) return null;
    return ConversationSummary(
      id: id,
      title: title,
      created: json['created'] is String ? json['created'] as String : '',
      updated: json['updated'] is String ? json['updated'] as String : '',
      mode: json['mode'] is String ? json['mode'] as String : 'data',
    );
  }

  static List<ConversationSummary> listFromJson(Object? json) {
    if (json is! List) return const [];
    return [
      for (final item in json)
        if (tryFromJson(item) case final c?) c,
    ];
  }
}

/// Full conversation from `GET /conversations/{id}` (D-128).
class ConversationDetail {
  const ConversationDetail({
    required this.conversation,
    required this.messages,
  });

  final ConversationSummary conversation;
  final List<ChatMessage> messages;

  static ConversationDetail? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final conv = ConversationSummary.tryFromJson(json['conversation']);
    if (conv == null) return null;
    final rawMsgs = json['messages'];
    final messages = <ChatMessage>[];
    if (rawMsgs is List) {
      for (final item in rawMsgs) {
        final msg = _parseStoredMessage(item);
        if (msg != null) messages.add(msg);
      }
    }
    return ConversationDetail(conversation: conv, messages: messages);
  }

  static ChatMessage? _parseStoredMessage(Object? json) {
    if (json is! Map) return null;
    final roleRaw = json['role'];
    final text = json['text'];
    if (roleRaw is! String || text is! String) return null;
    final role = roleRaw == 'user' ? ChatRole.user : ChatRole.assistant;
    final created = json['created'];
    final at = created is String ? DateTime.tryParse(created)?.toLocal() : null;
    final elapsed = json['elapsed_ms'];
    return ChatMessage.stored(
      role: role,
      text: text,
      source: role == ChatRole.assistant
          ? ChatSource.parse(json['source'])
          : null,
      tool: ChatToolCall.tryFromJson(json['tool']),
      result: json['result'],
      elapsedMs: elapsed is num ? elapsed.toInt() : null,
      model: AnsweringModel.tryFromJson(json['model']),
      at: at,
    );
  }
}

/// One hit from `GET /conversations/search?q=` (D-128).
class ConversationSearchHit {
  const ConversationSearchHit({
    required this.conversationId,
    required this.title,
    required this.snippet,
    this.role = 'user',
    this.created = '',
  });

  final String conversationId;
  final String title;
  final String snippet;
  final String role;
  final String created;

  static ConversationSearchHit? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final cid = json['conversation_id'];
    final title = json['title'];
    if (cid is! String || cid.isEmpty || title is! String) return null;
    return ConversationSearchHit(
      conversationId: cid,
      title: title,
      snippet: json['snippet'] is String ? json['snippet'] as String : '',
      role: json['role'] is String ? json['role'] as String : 'user',
      created: json['created'] is String ? json['created'] as String : '',
    );
  }

  static List<ConversationSearchHit> listFromJson(Object? json) {
    if (json is! List) return const [];
    return [
      for (final item in json)
        if (tryFromJson(item) case final hit?) hit,
    ];
  }
}

/// One saved rider fact from `/assistant/memory` (D-128).
class MemoryFact {
  const MemoryFact({
    required this.key,
    required this.value,
    this.created = '',
    this.updated = '',
  });

  final String key;
  final String value;
  final String created;
  final String updated;

  static MemoryFact? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final value = json['value'];
    if (key is! String || key.isEmpty || value is! String) return null;
    return MemoryFact(
      key: key,
      value: value,
      created: json['created'] is String ? json['created'] as String : '',
      updated: json['updated'] is String ? json['updated'] as String : '',
    );
  }

  static List<MemoryFact> listFromJson(Object? json) {
    if (json is! List) return const [];
    return [
      for (final item in json)
        if (tryFromJson(item) case final fact?) fact,
    ];
  }
}
