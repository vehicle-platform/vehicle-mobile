import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/assistant_provider.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/assistant_provider_client.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';

/// Summary line of the current choice, e.g. "Local model (default)".
String assistantChoiceSummary(AppLocalizations l, AssistantChoice choice,
    List<AssistantProvider> providers) {
  if (choice.isLocal) return l.settingsModelLocal;
  final label = providers
      .where((p) => p.id == choice.provider)
      .map((p) => p.label)
      .firstOrNull;
  final name = label ?? choice.provider;
  final model = choice.model;
  return model == null || model.isEmpty ? name : '$name · $model';
}

/// Localized text of a failed provider call.
String providerFailureText(AppLocalizations l, ProviderResult<Object?> r) =>
    switch (r.outcome) {
      ProviderOutcome.consentRequired => l.settingsModelConsentRequired,
      ProviderOutcome.cloudDisabled => l.settingsModelCloudDisabled,
      ProviderOutcome.providerError => l.settingsModelProviderError,
      ProviderOutcome.invalid => r.message == null
          ? l.settingsModelInvalid
          : l.settingsModelInvalidDetail(r.message!),
      ProviderOutcome.unauthorized => l.settingsSessionEnded,
      ProviderOutcome.unreachable => l.settingsUnreachable,
      ProviderOutcome.notSupported => l.settingsModelNotSupported,
      _ => l.settingsModelFailed(r.message ?? l.settingsUnknownError),
    };

/// Settings row "Assistant model": shows the current choice and opens
/// [AssistantModelScreen]. Renders nothing when the server answers 404 (an
/// older server without these routes); other failures show a retry row.
class AssistantModelSection extends StatefulWidget {
  const AssistantModelSection({super.key, required this.store, this.client});

  final AppSettingsStore store;
  final AssistantProviderClient? client;

  @override
  State<AssistantModelSection> createState() => _AssistantModelSectionState();
}

class _AssistantModelSectionState extends State<AssistantModelSection> {
  late final AssistantProviderClient _client =
      widget.client ?? AssistantProviderClient();
  bool _loading = true;
  bool _hidden = false;
  AssistantChoice? _choice;
  List<AssistantProvider> _providers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<(String, String)?> _target() async {
    final s = await widget.store.load();
    final token = s.apiToken ?? '';
    if (!s.isServerConfigured || token.isEmpty) return null;
    return (s.serverBaseUrl!, token);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final target = await _target();
    if (target == null) {
      if (mounted) setState(() => _hidden = true);
      return;
    }
    final choice = await _client.current(baseUrl: target.$1, token: target.$2);
    if (!mounted) return;
    if (choice.outcome == ProviderOutcome.notSupported) {
      setState(() => _hidden = true);
      return;
    }
    List<AssistantProvider> providers = const [];
    if (choice.isSuccess) {
      providers =
          (await _client.providers(baseUrl: target.$1, token: target.$2))
                  .value ??
              const [];
    }
    if (!mounted) return;
    setState(() {
      _choice = choice.isSuccess ? choice.value : null;
      _providers = providers;
      _loading = false;
    });
  }

  Future<void> _open() async {
    final target = await _target();
    if (target == null || !mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => AssistantModelScreen(
            baseUrl: target.$1, token: target.$2, client: _client)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l = context.l10n;
    final choice = _choice;
    final summary =
        choice == null ? null : assistantChoiceSummary(l, choice, _providers);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.lg),
        SectionLabel(l.settingsModelTitle),
        SectionCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            key: const ValueKey('assistant-model-row'),
            leading: const Icon(Icons.tune),
            title: Text(
                _loading
                    ? l.settingsModelLoading
                    : (summary ?? l.settingsModelUnreadable),
                style: theme.textTheme.titleSmall),
            subtitle: Text(l.settingsModelSubtitle(l.assistantName),
                style: theme.textTheme.bodySmall),
            trailing: const Icon(Icons.chevron_right),
            onTap: _loading ? null : (summary == null ? _load : _open),
          ),
        ),
      ],
    );
  }
}

/// Provider list, model, key and consent of the assistant model (D-124).
class AssistantModelScreen extends StatefulWidget {
  const AssistantModelScreen(
      {super.key, required this.baseUrl, required this.token, this.client});

  final String baseUrl;
  final String token;
  final AssistantProviderClient? client;

  @override
  State<AssistantModelScreen> createState() => _AssistantModelScreenState();
}

class _AssistantModelScreenState extends State<AssistantModelScreen> {
  late final AssistantProviderClient _client =
      widget.client ?? AssistantProviderClient();
  final _key = TextEditingController();
  final _model = TextEditingController();
  final _url = TextEditingController();

  bool _loading = true;
  String? _loadError;
  List<AssistantProvider> _providers = const [];
  AssistantChoice? _saved;
  List<AssistantModel> _models = const [];
  String _selected = localProviderId;
  bool _consent = false;
  bool _allowPosition = false;
  bool _saving = false;
  bool _testing = false;
  String? _message;
  Tone _messageTone = Tone.neutral;
  bool _insecure = false;
  ProviderTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _url.dispose();
    super.dispose();
  }

  AssistantProvider? get _provider =>
      _providers.where((p) => p.id == _selected).firstOrNull;

  bool get _isSavedProvider => _saved?.provider == _selected;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final providers =
        await _client.providers(baseUrl: widget.baseUrl, token: widget.token);
    final current =
        await _client.current(baseUrl: widget.baseUrl, token: widget.token);
    if (!mounted) return;
    if (!providers.isSuccess || !current.isSuccess) {
      setState(() {
        _loading = false;
        _loadError = providerFailureText(
            context.l10n, providers.isSuccess ? current : providers);
      });
      return;
    }
    _providers = providers.value!;
    _applySaved(current.value!);
    setState(() => _loading = false);
    await _loadModels();
  }

  void _applySaved(AssistantChoice choice) {
    _saved = choice;
    _selected = choice.provider;
    _consent = choice.consentCloud;
    _allowPosition = choice.allowPosition;
    _model.text = choice.model ?? _provider?.defaultModel ?? '';
    _url.text = choice.baseUrl ?? _provider?.baseUrl ?? '';
  }

  Future<void> _loadModels() async {
    final provider = _provider;
    if (provider == null ||
        provider.isLocal ||
        !_isSavedProvider ||
        _saved?.hasKey != true) {
      if (mounted) setState(() => _models = const []);
      return;
    }
    final result =
        await _client.models(baseUrl: widget.baseUrl, token: widget.token);
    if (!mounted) return;
    setState(() => _models = result.isSuccess ? result.value! : const []);
  }

  Future<void> _select(AssistantProvider p) async {
    if (!p.available || p.id == _selected) return;
    var consent = false;
    var allowPosition = false;
    if (p.cloud) {
      if (_saved?.provider == p.id && _saved!.consentCloud) {
        consent = true;
        allowPosition = _saved!.allowPosition;
      } else {
        final result = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _ConsentSheet(provider: p),
        );
        if (result == null || !mounted) return;
        consent = true;
        allowPosition = result;
      }
    }
    setState(() {
      _selected = p.id;
      _consent = consent;
      _allowPosition = allowPosition;
      _key.clear();
      _models = const [];
      _model.text = (_saved?.provider == p.id ? _saved!.model : null) ??
          p.defaultModel ??
          '';
      _url.text = (_saved?.provider == p.id ? _saved!.baseUrl : null) ??
          p.baseUrl ??
          '';
      _message = null;
      _insecure = false;
      _testResult = null;
    });
    await _loadModels();
  }

  bool get _canSave {
    final p = _provider;
    if (p == null || _saving) return false;
    if (p.cloud && !_consent) return false;
    if (p.isCustom && _url.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _save({bool deleteKey = false}) async {
    final p = _provider;
    if (p == null || !_canSave) return;
    // The key goes into this one request and the field is cleared at once.
    final typed = _key.text.trim();
    final String? apiKey = deleteKey ? '' : (typed.isEmpty ? null : typed);
    _key.clear();
    setState(() {
      _saving = true;
      _message = null;
      _insecure = false;
    });
    final result = await _client.save(
      baseUrl: widget.baseUrl,
      token: widget.token,
      provider: p.id,
      model: p.isLocal ? null : _model.text.trim(),
      providerBaseUrl: p.isCustom ? _url.text.trim() : null,
      apiKey: p.isLocal ? null : apiKey,
      consentCloud: p.cloud && _consent,
      allowPosition: p.cloud && _consent && _allowPosition,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _saving = false;
        _applySaved(result.value!);
        _message = deleteKey
            ? context.l10n.settingsModelKeyDeleted
            : context.l10n.settingsModelSaved;
        _messageTone = Tone.ok;
        _testResult = null;
      });
      await _loadModels();
      return;
    }
    setState(() {
      _saving = false;
      _insecure = result.outcome == ProviderOutcome.insecureTransport;
      _message = _insecure ? null : providerFailureText(context.l10n, result);
      _messageTone = Tone.error;
    });
  }

  Future<void> _confirmDeleteKey() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.settingsModelDeleteKeyTitle),
        content: Text(ctx.l10n.settingsModelDeleteKeyBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.settingsDismiss)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.settingsDelete)),
        ],
      ),
    );
    if (ok == true) await _save(deleteKey: true);
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
      _message = null;
    });
    final result =
        await _client.test(baseUrl: widget.baseUrl, token: widget.token);
    if (!mounted) return;
    setState(() {
      _testing = false;
      if (result.isSuccess) {
        _testResult = result.value;
      } else {
        _message = providerFailureText(context.l10n, result);
        _messageTone = Tone.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsModelTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentColumn(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
                child: _loadError != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InfoBanner(
                              icon: Icons.error_outline,
                              tone: Tone.error,
                              text: _loadError!),
                          const SizedBox(height: Spacing.md),
                          OutlinedButton(
                              onPressed: _load,
                              child: Text(context.l10n.settingsRetry)),
                        ],
                      )
                    : _form(context),
              ),
            ),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    final l = context.l10n;
    final p = _provider;
    final saved = _saved;
    final showSavedKey = p != null &&
        p.needsKey &&
        _isSavedProvider &&
        saved != null &&
        saved.hasKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.settingsModelIntro(l.assistantName),
          style: theme.textTheme.bodySmall!.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: Spacing.md),
        SectionLabel(l.settingsModelProvider),
        for (final provider in _providers) _providerTile(context, provider),
        if (p != null && p.needsKey) ...[
          const SizedBox(height: Spacing.lg),
          SectionLabel(l.settingsModelConnection),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (p.isCustom) ...[
                  TextField(
                    key: const ValueKey('provider-url'),
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                        labelText: l.settingsModelBaseUrl,
                        hintText: 'https://api.example.com/v1'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Spacing.md),
                ],
                if (!showSavedKey) ...[
                  Text(
                    p.isCustom
                        ? l.settingsModelKeyHelpCustom
                        : l.settingsModelKeyHelp(p.label),
                    key: const ValueKey('key-help'),
                    style: theme.textTheme.bodySmall!
                        .copyWith(color: t.textSecondary),
                  ),
                  const SizedBox(height: Spacing.sm),
                ],
                if (showSavedKey) ...[
                  Row(children: [
                    Expanded(
                      child: Text(l.settingsModelSavedKey(saved.keyHint ?? ''),
                          key: const ValueKey('key-hint'),
                          style: theme.textTheme.bodyMedium),
                    ),
                    TextButton(
                      key: const ValueKey('delete-key'),
                      onPressed: _saving ? null : _confirmDeleteKey,
                      child: Text(l.settingsModelDeleteKey),
                    ),
                  ]),
                  const SizedBox(height: Spacing.sm),
                ],
                TextField(
                  key: const ValueKey('provider-key'),
                  controller: _key,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                      labelText: showSavedKey
                          ? l.settingsModelNewKey
                          : l.settingsModelApiKey),
                ),
                const SizedBox(height: Spacing.md),
                _modelField(l),
                if (p.cloud) ...[
                  const SizedBox(height: Spacing.sm),
                  SwitchListTile(
                    key: const ValueKey('allow-position'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.settingsModelSendPosition,
                        style: theme.textTheme.titleSmall),
                    subtitle: Text(l.settingsModelSendPositionHint,
                        style: theme.textTheme.bodySmall),
                    value: _allowPosition,
                    onChanged: (v) => setState(() => _allowPosition = v),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_insecure) ...[
          const SizedBox(height: Spacing.md),
          InfoBanner(
            key: const ValueKey('insecure-banner'),
            icon: Icons.lock_outline,
            tone: Tone.warn,
            title: l.settingsModelInsecureTitle,
            text: l.settingsModelInsecureText,
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: Spacing.md),
          InfoBanner(
              icon: _messageTone == Tone.ok
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              tone: _messageTone,
              text: _message!),
        ],
        const SizedBox(height: Spacing.lg),
        FilledButton(
          key: const ValueKey('save-provider'),
          onPressed: _canSave ? _save : null,
          child: Text(_saving ? l.settingsSaving : l.settingsSave),
        ),
        if (p != null && !p.isLocal && _isSavedProvider) ...[
          const SizedBox(height: Spacing.sm),
          OutlinedButton(
            key: const ValueKey('test-provider'),
            onPressed: _testing ? null : _test,
            child:
                Text(_testing ? l.settingsModelTesting : l.settingsModelTest),
          ),
        ],
        if (_testResult != null) ...[
          const SizedBox(height: Spacing.md),
          InfoBanner(
            key: const ValueKey('test-result'),
            icon: _testResult!.ok
                ? Icons.check_circle_outline
                : Icons.error_outline,
            tone: _testResult!.ok ? Tone.ok : Tone.error,
            text: _testResult!.ok
                ? l.settingsModelTestOk(_testResult!.latencyMs)
                : l.settingsModelTestFailed(_testResult!.detail),
          ),
        ],
      ],
    );
  }

  Widget _modelField(AppLocalizations l) {
    if (_models.isNotEmpty) {
      final ids = _models.map((m) => m.id).toList();
      final current = _model.text.trim();
      final value = ids.contains(current)
          ? current
          : (ids.contains(_provider?.defaultModel)
              ? _provider!.defaultModel
              : null);
      if (value != null && value != current) _model.text = value;
      return DropdownButtonFormField<String>(
        key: ValueKey('model-dropdown-$_selected-${ids.length}'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.settingsModelLabel),
        items: [
          for (final m in _models)
            DropdownMenuItem(value: m.id, child: Text(m.label)),
        ],
        onChanged: (v) => setState(() => _model.text = v ?? ''),
      );
    }
    return TextField(
      key: const ValueKey('model-text'),
      controller: _model,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: l.settingsModelLabel,
        helperText: _saved?.hasKey == true && _isSavedProvider
            ? l.settingsModelListFailed
            : l.settingsModelListLater,
      ),
    );
  }

  Widget _providerTile(BuildContext context, AssistantProvider p) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    final l = context.l10n;
    final selected = p.id == _selected;
    final enabled = p.available;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: selected ? t.accent : Colors.transparent, width: 3),
          bottom: BorderSide(color: t.hairline),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          key: ValueKey('provider-${p.id}'),
          enabled: enabled,
          leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? t.accent : null),
          title: Text(p.label, style: theme.textTheme.titleSmall),
          subtitle: Text(
            enabled
                ? p.dataNote
                : (p.unavailableReason ?? l.settingsModelUnavailable),
            key: ValueKey('provider-note-${p.id}'),
            style: enabled
                ? theme.textTheme.bodySmall
                : theme.textTheme.bodySmall!.copyWith(color: t.stale),
          ),
          trailing: p.cloud
              ? Tooltip(
                  message: l.settingsModelCloud,
                  child: const Icon(Icons.cloud_outlined))
              : null,
          onTap: enabled ? () => _select(p) : null,
        ),
      ),
    );
  }
}

/// Plain statement of what leaves the server before a cloud provider can be
/// saved (D-124). Pops `true` or `false` = "also send position" after the
/// user accepted; pops `null` when dismissed, so nothing is selected.
class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet({required this.provider});

  final AssistantProvider provider;

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool _position = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final label = widget.provider.label;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg,
            Spacing.lg + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.settingsModelConsentTitle(label),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.md),
            Text(
              l.settingsModelConsentText(label),
              key: const ValueKey('consent-text'),
              style: theme.textTheme.bodyMedium,
            ),
            if (widget.provider.dataNote.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              Text(widget.provider.dataNote, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: Spacing.sm),
            SwitchListTile(
              key: const ValueKey('consent-position'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsModelSendPosition,
                  style: theme.textTheme.titleSmall),
              value: _position,
              onChanged: (v) => setState(() => _position = v),
            ),
            const SizedBox(height: Spacing.md),
            FilledButton(
              key: const ValueKey('consent-accept'),
              onPressed: () => Navigator.pop(context, _position),
              child: Text(l.settingsModelAccept),
            ),
            TextButton(
              key: const ValueKey('consent-cancel'),
              onPressed: () => Navigator.pop(context),
              child: Text(l.settingsDismiss),
            ),
          ],
        ),
      ),
    );
  }
}
