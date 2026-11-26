import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/conversation.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/chat_export.dart';
import 'package:vehicle_mobile/services/conversations_client.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';

/// Settings row "Assistant memory" (D-128): opens [AssistantMemoryScreen].
/// Hides quietly when the server does not support memory routes (403/404).
class AssistantMemorySection extends StatefulWidget {
  const AssistantMemorySection({
    super.key,
    required this.store,
    this.client,
    this.exporter,
  });

  final AppSettingsStore store;
  final ConversationsClient? client;
  final ChatExporter? exporter;

  @override
  State<AssistantMemorySection> createState() => _AssistantMemorySectionState();
}

class _AssistantMemorySectionState extends State<AssistantMemorySection> {
  late final ConversationsClient _client =
      widget.client ?? ConversationsClient();

  Future<(String, String)?> _target() async {
    final s = await widget.store.load();
    final token = s.apiToken ?? '';
    if (!s.isServerConfigured || token.isEmpty) return null;
    return (s.serverBaseUrl!, token);
  }

  Future<void> _open() async {
    final target = await _target();
    if (target == null || !mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => AssistantMemoryScreen(
        baseUrl: target.$1,
        token: target.$2,
        client: _client,
        exporter: widget.exporter,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.lg),
        SectionLabel(l.settingsMemoryTitle),
        SectionCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            key: const ValueKey('assistant-memory-row'),
            leading: const Icon(Icons.memory_outlined),
            title: Text(l.settingsMemoryTitle,
                style: theme.textTheme.titleSmall),
            subtitle: Text(l.settingsMemorySubtitle,
                style: theme.textTheme.bodySmall),
            trailing: const Icon(Icons.chevron_right),
            onTap: _open,
          ),
        ),
      ],
    );
  }
}

/// Saved rider facts and chat export (D-128).
class AssistantMemoryScreen extends StatefulWidget {
  const AssistantMemoryScreen({
    super.key,
    required this.baseUrl,
    required this.token,
    this.client,
    this.exporter,
  });

  final String baseUrl;
  final String token;
  final ConversationsClient? client;
  final ChatExporter? exporter;

  @override
  State<AssistantMemoryScreen> createState() => _AssistantMemoryScreenState();
}

class _AssistantMemoryScreenState extends State<AssistantMemoryScreen> {
  late final ConversationsClient _client =
      widget.client ?? ConversationsClient();
  late final ChatExporter _exporter = widget.exporter ?? exportChatsFile;
  List<MemoryFact> _facts = const [];
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _client.listMemory(
        baseUrl: widget.baseUrl, token: widget.token);
    if (!mounted) return;
    if (res.isSuccess && res.value != null) {
      setState(() {
        _facts = res.value!;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = res.message ?? 'error';
      });
    }
  }

  Future<void> _edit(MemoryFact fact) async {
    final updated = await showDialog<String>(
      context: context,
      builder: (_) => _EditFactDialog(fact: fact),
    );
    if (updated == null || updated.isEmpty || updated == fact.value) return;
    final res = await _client.putMemory(
      baseUrl: widget.baseUrl,
      token: widget.token,
      key: fact.key,
      value: updated,
    );
    if (!mounted) return;
    if (res.isSuccess && res.value != null) {
      setState(() {
        _facts = [
          for (final item in _facts) item.key == fact.key ? res.value! : item,
        ];
      });
    }
  }

  Future<void> _deleteOne(MemoryFact fact) async {
    final res = await _client.deleteMemory(
      baseUrl: widget.baseUrl,
      token: widget.token,
      key: fact.key,
    );
    if (!mounted || !res.isSuccess) return;
    setState(() {
      _facts = _facts.where((f) => f.key != fact.key).toList(growable: false);
    });
  }

  Future<void> _deleteAll() async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsMemoryDeleteAllTitle),
        content: Text(l.settingsMemoryDeleteAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.settingsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.settingsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await _client.deleteAllMemory(
      baseUrl: widget.baseUrl,
      token: widget.token,
    );
    if (!mounted || !res.isSuccess) return;
    setState(() => _facts = const []);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.settingsMemoryDeletedAll)),
    );
  }

  Future<void> _exportChats() async {
    final l = context.l10n;
    setState(() => _exporting = true);
    final res = await _client.exportJson(
        baseUrl: widget.baseUrl, token: widget.token);
    if (!mounted) return;
    if (!res.isSuccess || res.value == null) {
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              l.settingsMemoryExportFailed(res.message ?? l.settingsUnknownError)),
        ),
      );
      return;
    }
    try {
      await _exporter('vehicle-assistant-chats.json', res.value!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.settingsMemoryExportDone)),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.settingsMemoryExportFailed('$err'))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.vehicle;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.settingsMemoryTitle),
        actions: [
          if (_facts.isNotEmpty)
            IconButton(
              key: const ValueKey('memory-delete-all-button'),
              tooltip: l.settingsMemoryDeleteAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _deleteAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentColumn(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      InfoBanner(
                        icon: Icons.error_outline,
                        tone: Tone.error,
                        text: l.settingsMemoryLoadFailed,
                      ),
                      const SizedBox(height: Spacing.md),
                      OutlinedButton(
                          onPressed: _load, child: Text(l.settingsRetry)),
                      const SizedBox(height: Spacing.lg),
                    ] else if (_facts.isEmpty) ...[
                      SectionCard(
                        child: Text(
                          l.settingsMemoryEmpty,
                          style: theme.textTheme.bodyMedium!
                              .copyWith(color: t.textSecondary),
                        ),
                      ),
                      const SizedBox(height: Spacing.lg),
                    ] else ...[
                      SectionCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < _facts.length; i++) ...[
                              if (i > 0)
                                Divider(
                                    height: 1, thickness: 1, color: t.hairline),
                              ListTile(
                                key: ValueKey('memory-fact-${_facts[i].key}'),
                                title: Text(_facts[i].value,
                                    style: theme.textTheme.bodyLarge),
                                subtitle: Text(
                                  _facts[i].key,
                                  style: theme.textTheme.labelSmall!
                                      .copyWith(color: t.textSecondary),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      key: ValueKey(
                                          'memory-edit-${_facts[i].key}'),
                                      tooltip: l.settingsMemoryEditTitle,
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _edit(_facts[i]),
                                    ),
                                    IconButton(
                                      key: ValueKey(
                                          'memory-delete-${_facts[i].key}'),
                                      tooltip: l.settingsDelete,
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _deleteOne(_facts[i]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.lg),
                    ],
                    SectionLabel(l.settingsMemoryExport),
                    SectionCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        key: const ValueKey('export-chats-row'),
                        leading: _exporting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_outlined),
                        title: Text(l.settingsMemoryExport,
                            style: theme.textTheme.titleSmall),
                        subtitle: Text(l.settingsMemoryExportSubtitle,
                            style: theme.textTheme.bodySmall),
                        onTap: _exporting ? null : _exportChats,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _EditFactDialog extends StatefulWidget {
  const _EditFactDialog({required this.fact});

  final MemoryFact fact;

  @override
  State<_EditFactDialog> createState() => _EditFactDialogState();
}

class _EditFactDialogState extends State<_EditFactDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.fact.value);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.settingsMemoryEditTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.fact.key, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: Spacing.sm),
          TextField(
            key: const ValueKey('memory-edit-field'),
            controller: _ctrl,
            autofocus: true,
            maxLength: 200,
            decoration: InputDecoration(labelText: l.settingsMemoryValueLabel),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.settingsCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(l.settingsSave),
        ),
      ],
    );
  }
}
