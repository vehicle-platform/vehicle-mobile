/// Provider catalogue and per-user choice of the rider assistant's language
/// model (D-124). Plain data parsed from vehicle-server's `/assistant/*`
/// routes; nothing here is computed on the phone.
library;

/// Provider id that selects the server's own local model.
const String localProviderId = 'local';

/// Provider id of the free-form OpenAI-compatible endpoint (needs a base URL).
const String customProviderId = 'custom';

class AssistantProvider {
  const AssistantProvider({
    required this.id,
    required this.label,
    required this.kind,
    required this.cloud,
    this.baseUrl,
    this.defaultModel,
    this.hasModelsEndpoint = false,
    this.dataNote = '',
    this.available = true,
    this.unavailableReason,
  });

  final String id;
  final String label;

  /// `local`, `anthropic` or `openai_compatible`.
  final String kind;

  /// True when the question and ride data leave the user's own server.
  final bool cloud;
  final String? baseUrl;
  final String? defaultModel;
  final bool hasModelsEndpoint;
  final String dataNote;
  final bool available;
  final String? unavailableReason;

  bool get isLocal => id == localProviderId;
  bool get isCustom => id == customProviderId;

  /// Local providers take no key; every other one is used with the user's key.
  bool get needsKey => !isLocal;

  static AssistantProvider? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final label = json['label'];
    return AssistantProvider(
      id: id,
      label: label is String && label.isNotEmpty ? label : id,
      kind: json['kind'] is String ? json['kind'] as String : '',
      cloud: json['cloud'] == true,
      baseUrl: json['base_url'] is String ? json['base_url'] as String : null,
      defaultModel: json['default_model'] is String
          ? json['default_model'] as String
          : null,
      hasModelsEndpoint: json['has_models_endpoint'] == true,
      dataNote: json['data_note'] is String ? json['data_note'] as String : '',
      available: json['available'] != false,
      unavailableReason: json['unavailable_reason'] is String
          ? json['unavailable_reason'] as String
          : null,
    );
  }

  static List<AssistantProvider> listFromJson(Object? json) {
    if (json is! List) return const [];
    return [
      for (final item in json)
        if (tryFromJson(item) case final p?) p,
    ];
  }
}

/// The signed-in user's stored choice. The key itself never comes back, only
/// whether one is set and a short [keyHint] (its last characters).
class AssistantChoice {
  const AssistantChoice({
    required this.provider,
    this.model,
    this.baseUrl,
    this.hasKey = false,
    this.keyHint,
    this.consentCloud = false,
    this.allowPosition = false,
    this.updatedUtc,
  });

  final String provider;
  final String? model;
  final String? baseUrl;
  final bool hasKey;
  final String? keyHint;
  final bool consentCloud;
  final bool allowPosition;
  final String? updatedUtc;

  bool get isLocal => provider == localProviderId;

  static AssistantChoice? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final provider = json['provider'];
    if (provider is! String || provider.isEmpty) return null;
    return AssistantChoice(
      provider: provider,
      model: json['model'] is String ? json['model'] as String : null,
      baseUrl: json['base_url'] is String ? json['base_url'] as String : null,
      hasKey: json['has_key'] == true,
      keyHint: json['key_hint'] is String ? json['key_hint'] as String : null,
      consentCloud: json['consent_cloud'] == true,
      allowPosition: json['allow_position'] == true,
      updatedUtc:
          json['updated_utc'] is String ? json['updated_utc'] as String : null,
    );
  }
}

class AssistantModel {
  const AssistantModel({required this.id, required this.label});

  final String id;
  final String label;

  static List<AssistantModel> listFromJson(Object? json) {
    if (json is! List) return const [];
    final out = <AssistantModel>[];
    for (final item in json) {
      if (item is Map &&
          item['id'] is String &&
          (item['id'] as String).isNotEmpty) {
        final label = item['label'];
        out.add(AssistantModel(
            id: item['id'] as String,
            label: label is String && label.isNotEmpty
                ? label
                : item['id'] as String));
      }
    }
    return out;
  }
}

class ProviderTestResult {
  const ProviderTestResult(
      {required this.ok, required this.latencyMs, required this.detail});

  final bool ok;
  final int latencyMs;
  final String detail;
}
