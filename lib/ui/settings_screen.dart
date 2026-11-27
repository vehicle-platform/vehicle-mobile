import 'package:flutter/material.dart';

import 'package:vehicle_mobile/ui/theme/theme_controller.dart';
import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/l10n/locale_controller.dart';
import 'package:vehicle_mobile/models/host.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/assistant_provider_client.dart';
import 'package:vehicle_mobile/services/auth_client.dart';
import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:vehicle_mobile/services/auth_store.dart';
import 'package:vehicle_mobile/services/chat_export.dart';
import 'package:vehicle_mobile/services/conversations_client.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/services/token_guard.dart';
import 'package:vehicle_mobile/services/voice/voice_settings.dart';
import 'package:vehicle_mobile/ui/notifications/notification_scope.dart';
import 'package:vehicle_mobile/ui/settings/alert_types_section.dart';
import 'package:vehicle_mobile/ui/settings/assistant_memory_screen.dart';
import 'package:vehicle_mobile/ui/settings/assistant_model_screen.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';

/// Host list and upload policy (D-121 item 4). The list is the rider's own
/// vehicle-servers in priority order (local first); the app uses the first one
/// that answers `GET /health`. Each host keeps its own device token in the
/// platform keystore. Recording and sharing sessions never depend on any of
/// this being filled in -- only the server features do.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen(
      {super.key,
      this.store = const AppSettingsStore(),
      this.onSaved,
      this.authClient,
      this.assistantClient,
      this.conversationsClient,
      this.chatExporter});

  final AppSettingsStore store;

  /// Account calls (logout, claim a vehicle); a default client when null.
  final AuthClient? authClient;

  /// Assistant model routes (D-124); a default client when null.
  final AssistantProviderClient? assistantClient;

  /// Conversations and memory routes (D-128); a default client when null.
  final ConversationsClient? conversationsClient;

  /// File export hook for "Export my chats"; injectable for tests.
  final ChatExporter? chatExporter;

  /// Called after hosts or the upload policy changed (the shell uses it to
  /// refresh screens that depend on them, e.g. the upload action in Record).
  final VoidCallback? onSaved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Host> _hosts = const [];
  final Map<String, bool> _hasToken = {};
  String? _activeId;
  bool _uploadOnlyOnWifi = true;
  bool _readAnswers = defaultReadAnswers();
  bool _loading = true;
  bool _checking = false;
  bool _loadFailed = false;
  AccountInfo? _account;
  bool _hasSession = false;
  String? _accountMessage;
  late final AuthClient _auth = widget.authClient ?? AuthClient();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reprobe = false}) async {
    final hostStore = widget.store.hosts;
    List<Host> hosts;
    AppSettings settings;
    var readAnswers = defaultReadAnswers();
    final tokens = <String, bool>{};
    AccountInfo? account;
    try {
      hosts = await hostStore.load();
      settings = await widget.store.load(reprobe: reprobe);
      for (final host in hosts) {
        tokens[host.id] = (await hostStore.readToken(host.id)) != null;
      }
      readAnswers = await const VoiceSettings().readAnswers();
      if (settings.hostId != null) {
        account = await AuthStore(hostStore).readAccount(settings.hostId!);
      }
    } catch (_) {
      // Keystore or preferences unavailable: show an empty list, never a spinner forever.
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _loading = false;
        _checking = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _hosts = hosts;
      _hasToken
        ..clear()
        ..addAll(tokens);
      _activeId = settings.hostId;
      _account = account;
      _hasSession = (settings.apiToken ?? '').isNotEmpty;
      _uploadOnlyOnWifi = settings.uploadOnlyOnWifi;
      _readAnswers = readAnswers;
      _loading = false;
      _checking = false;
      _loadFailed = false;
    });
  }

  Future<void> _changed() async {
    HostResolver.invalidate();
    widget.onSaved?.call();
    await _load();
  }

  Future<void> _addOrEdit([Host? existing]) async {
    final hostStore = widget.store.hosts;
    final token =
        existing == null ? null : await hostStore.readToken(existing.id);
    if (!mounted) return;
    final edited = await showDialog<HostEdit>(
      context: context,
      builder: (_) => HostEditDialog(existing: existing, existingToken: token),
    );
    if (edited == null) return;
    final id = existing?.id ?? newHostId();
    final host = Host(id: id, name: edited.name, baseUrl: edited.baseUrl);
    final list = [..._hosts];
    final index = list.indexWhere((h) => h.id == id);
    if (index < 0) {
      list.add(host);
    } else {
      list[index] = host;
    }
    await hostStore.saveHosts(list);
    await hostStore.writeToken(id, edited.token);
    await _changed();
  }

  Future<void> _delete(Host host) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.settingsDeleteHostTitle),
        content: Text(ctx.l10n.settingsDeleteHostBody(host.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.settingsCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.settingsDelete)),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.hosts.deleteHost(host.id);
    await _changed();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final list = [..._hosts];
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() => _hosts = list);
    await widget.store.hosts.saveHosts(list);
    await _changed();
  }

  Future<void> _logout() async {
    final settings = await widget.store.load();
    final id = settings.hostId;
    if (id == null) return;
    final token = settings.apiToken ?? '';
    // Revoke on the server when there is an account session; the local session
    // is dropped even when the server cannot be reached.
    if (_account != null && token.isNotEmpty && settings.isServerConfigured) {
      await _auth.logout(baseUrl: settings.serverBaseUrl!, token: token);
    }
    await AuthStore(widget.store.hosts).clearSession(id);
    HostResolver.invalidate();
    widget.onSaved?.call();
    await _load();
  }

  Future<void> _claim() async {
    final input = await showDialog<(String, String)>(
        context: context, builder: (_) => const _ClaimDialog());
    if (input == null) return;
    final settings = await widget.store.load();
    final id = settings.hostId;
    if (id == null || !settings.isServerConfigured) return;
    final result = await _auth.claimVehicle(
      baseUrl: settings.serverBaseUrl!,
      token: settings.apiToken ?? '',
      vehicleId: input.$1,
      claimCode: input.$2,
    );
    if (!mounted) return;
    if (result.isSuccess && result.vehicles != null) {
      final store = AuthStore(widget.store.hosts);
      final current = _account;
      if (current != null) {
        await store.saveAccount(
            id,
            AccountInfo(
                username: current.username, vehicles: result.vehicles!));
      }
      setState(() => _accountMessage = null);
      await _load();
    } else {
      setState(() =>
          _accountMessage = authFailureTextForClaim(context.l10n, result));
    }
  }

  Future<void> _recheck() async {
    setState(() => _checking = true);
    await _load(reprobe: true);
    widget.onSaved?.call();
  }

  Future<void> _setReadAnswers(bool value) async {
    setState(() => _readAnswers = value);
    await const VoiceSettings().setReadAnswers(value);
  }

  Future<void> _setWifiOnly(bool value) async {
    setState(() => _uploadOnlyOnWifi = value);
    await widget.store.save(AppSettings(uploadOnlyOnWifi: value));
    widget.onSaved?.call();
  }

  Widget _languageSection(BuildContext context) {
    final controller = LocaleScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final l = context.l10n;
    final code = controller.override?.languageCode ?? 'en';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.settingsLanguage),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
            ButtonSegment(value: 'tr', label: Text(l.languageTurkish)),
          ],
          selected: {code},
          onSelectionChanged: (s) => controller.set(Locale(s.first)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: Spacing.sm),
          child: Text(l.settingsLanguageHint,
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _displaySection(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.settingsDisplay),
        SegmentedButton<ThemeChoice>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
                value: ThemeChoice.system, label: Text(l.themeSystem)),
            ButtonSegment(value: ThemeChoice.dark, label: Text(l.themeDark)),
            ButtonSegment(value: ThemeChoice.light, label: Text(l.themeLight)),
            ButtonSegment(
                value: ThemeChoice.sunlight, label: Text(l.themeSunlight)),
          ],
          selected: {controller.choice},
          onSelectionChanged: (s) => controller.set(s.first),
        ),
        Padding(
          padding: const EdgeInsets.only(top: Spacing.sm),
          child: Text(l.settingsDisplayHint,
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navSettings),
        actions: const [NotificationBell()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentColumn(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _accountSection(context),
                    const SizedBox(height: Spacing.lg),
                    _hostsSection(context),
                    const SizedBox(height: Spacing.lg),
                    _languageSection(context),
                    const SizedBox(height: Spacing.lg),
                    _displaySection(context),
                    const SizedBox(height: Spacing.lg),
                    const AlertTypesSection(),
                    const SizedBox(height: Spacing.lg),
                    SectionLabel(l.settingsUpload),
                    SectionCard(
                      child: _SwitchRow(
                        title: l.settingsWifiOnly,
                        subtitle: l.settingsWifiOnlyHint,
                        value: _uploadOnlyOnWifi,
                        onChanged: _setWifiOnly,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    SectionLabel(l.assistantName),
                    SectionCard(
                      child: _SwitchRow(
                        title: l.settingsReadAnswers,
                        subtitle: l.settingsReadAnswersHint(l.assistantName),
                        value: _readAnswers,
                        onChanged: _setReadAnswers,
                      ),
                    ),
                    if (_account != null) ...[
                      AssistantModelSection(
                          key: ValueKey('assistant-model-$_activeId'),
                          store: widget.store,
                          client: widget.assistantClient),
                      AssistantMemorySection(
                          key: ValueKey('assistant-memory-$_activeId'),
                          store: widget.store,
                          client: widget.conversationsClient,
                          exporter: widget.chatExporter),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _hostsSection(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final t = context.vehicle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          l.settingsHosts,
          trailing: IconButton(
            tooltip: l.settingsAddHost,
            icon: const Icon(Icons.add),
            onPressed: () => _addOrEdit(),
          ),
        ),
        if (_loadFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: InfoBanner(
              icon: Icons.error_outline,
              tone: Tone.error,
              text: l.settingsHostsLoadFailed,
            ),
          ),
        if (_hosts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Text(l.settingsNoHosts,
                style: theme.textTheme.bodySmall!
                    .copyWith(color: t.textSecondary)),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Text(l.settingsHostsHint,
                style: theme.textTheme.bodySmall!
                    .copyWith(color: t.textSecondary)),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: _reorder,
            children: [
              for (var i = 0; i < _hosts.length; i++)
                _HostTile(
                  key: ValueKey(_hosts[i].id),
                  index: i,
                  host: _hosts[i],
                  active: _hosts[i].id == _activeId,
                  hasToken: _hasToken[_hosts[i].id] ?? false,
                  onEdit: () => _addOrEdit(_hosts[i]),
                  onDelete: () => _delete(_hosts[i]),
                ),
            ],
          ),
          if (_hosts.length > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _checking ? null : _recheck,
                icon: const Icon(Icons.refresh),
                label:
                    Text(_checking ? l.settingsChecking : l.settingsCheckHosts),
              ),
            ),
        ],
      ],
    );
  }

  Widget _accountSection(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final account = _account;
    final children = <Widget>[];
    if (account != null) {
      children.add(Text(l.settingsSignedInAs(account.username),
          style: theme.textTheme.titleSmall));
      if (account.vehicles.isEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: Spacing.xs),
          child: Text(l.settingsNoVehicles, style: theme.textTheme.bodySmall),
        ));
      }
      for (final v in account.vehicles) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: Spacing.sm),
          child: Row(children: [
            const Icon(Icons.two_wheeler, size: IconSizes.regular),
            const SizedBox(width: Spacing.sm),
            Expanded(child: Text(v.name, style: theme.textTheme.bodyMedium)),
            Text(v.vehicleId, style: theme.textTheme.bodySmall),
          ]),
        ));
      }
    } else if (_hasSession) {
      children.add(Text(l.settingsDeviceTokenConnected,
          style: theme.textTheme.titleSmall));
    } else {
      children
          .add(Text(l.settingsNotSignedIn, style: theme.textTheme.titleSmall));
    }
    if (_accountMessage != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: Spacing.sm),
        child: InfoBanner(
            icon: Icons.info_outline, tone: Tone.error, text: _accountMessage!),
      ));
    }
    children.add(const SizedBox(height: Spacing.md));
    children.add(Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        if (account != null)
          OutlinedButton.icon(
            key: const ValueKey('claim-vehicle'),
            onPressed: _claim,
            icon: const Icon(Icons.add),
            label: Text(l.settingsAddVehicle),
          ),
        if (_hasSession)
          OutlinedButton.icon(
            key: const ValueKey('logout'),
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: Text(l.settingsSignOut),
          )
        else
          FilledButton(
            key: const ValueKey('request-login'),
            onPressed: () => AuthEvents.emit(AuthEvent.loginRequested),
            child: Text(l.settingsSignIn),
          ),
      ],
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.settingsAccount),
        SectionCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ],
    );
  }
}

/// Text of a failed vehicle claim.
String authFailureTextForClaim(AppLocalizations l, AuthResult result) =>
    switch (result.outcome) {
      AuthOutcome.forbidden => l.settingsClaimInvalid,
      AuthOutcome.rateLimited => l.settingsRateLimited,
      AuthOutcome.unreachable => l.settingsUnreachable,
      AuthOutcome.unauthorized => l.settingsSessionEnded,
      _ => l.settingsClaimFailed(result.message ?? l.settingsUnknownError),
    };

class _ClaimDialog extends StatefulWidget {
  const _ClaimDialog();

  @override
  State<_ClaimDialog> createState() => _ClaimDialogState();
}

class _ClaimDialogState extends State<_ClaimDialog> {
  final _vehicleId = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _vehicleId.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.settingsAddVehicle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _vehicleId,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l.settingsVehicleId),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _code,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l.settingsClaimCode),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.settingsCancel)),
        TextButton(
          onPressed: () {
            final id = _vehicleId.text.trim();
            final code = _code.text.trim();
            if (id.isEmpty || code.isEmpty) return;
            Navigator.pop(context, (id, code));
          },
          child: Text(l.settingsAdd),
        ),
      ],
    );
  }
}

class _HostTile extends StatelessWidget {
  const _HostTile({
    super.key,
    required this.index,
    required this.host,
    required this.active,
    required this.hasToken,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final Host host;
  final bool active;
  final bool hasToken;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.vehicle.hairline)),
      ),
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(0, Spacing.sm, Spacing.sm, Spacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Spacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(host.name, style: theme.textTheme.titleSmall),
                      if (active)
                        StatusPill(
                            icon: Icons.check_circle,
                            label: l.settingsHostActive,
                            tone: Tone.ok),
                    ],
                  ),
                  Text(host.baseUrl, style: theme.textTheme.bodySmall),
                  Text(hasToken ? l.settingsTokenSet : l.settingsNoToken,
                      style: theme.textTheme.bodySmall),
                  if (isCleartextRemoteUrl(host.baseUrl))
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.xs),
                      child: InfoBanner(
                        icon: Icons.warning_amber_rounded,
                        tone: Tone.warn,
                        text: l.settingsCleartextShort,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
                tooltip: l.settingsEditHost,
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit),
            IconButton(
                tooltip: l.settingsDeleteHost,
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete),
            ReorderableDragStartListener(
                index: index, child: const Icon(Icons.drag_handle)),
          ],
        ),
      ),
    );
  }
}

/// Result of [HostEditDialog].
class HostEdit {
  const HostEdit(
      {required this.name, required this.baseUrl, required this.token});

  final String name;
  final String baseUrl;
  final String token;
}

/// Add/edit form of one host. The URL must pass the same token guard the
/// clients apply (https, or http on the phone's own network), so a host that
/// could never be sent the token is refused up front.
class HostEditDialog extends StatefulWidget {
  const HostEditDialog({super.key, this.existing, this.existingToken});

  final Host? existing;
  final String? existingToken;

  @override
  State<HostEditDialog> createState() => _HostEditDialogState();
}

class _HostEditDialogState extends State<HostEditDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _url = TextEditingController(text: widget.existing?.baseUrl ?? '');
  late final _token = TextEditingController(text: widget.existingToken ?? '');
  String? _nameError;
  String? _urlError;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  void _submit() {
    final l = context.l10n;
    final name = _name.text.trim();
    final url = _url.text.trim();
    final nameError = name.isEmpty ? l.settingsEnterName : null;
    final refusal = tokenSendRefusal(url);
    final urlError = url.isEmpty
        ? l.settingsEnterUrl
        : (refusal == null ? null : _capitalize(refusal));
    if (nameError != null || urlError != null) {
      setState(() {
        _nameError = nameError;
        _urlError = urlError;
      });
      return;
    }
    Navigator.pop(
        context, HostEdit(name: name, baseUrl: url, token: _token.text.trim()));
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(
          widget.existing == null ? l.settingsAddHost : l.settingsEditHost),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: l.settingsHostName,
                  hintText: l.settingsHostNameHint,
                  errorText: _nameError),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l.settingsHostUrl,
                hintText: 'https://vehicle-server.example.com',
                errorText: _urlError,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _token,
              obscureText: true,
              decoration: InputDecoration(labelText: l.settingsHostToken),
            ),
            if (isCleartextRemoteUrl(_url.text))
              Padding(
                padding: const EdgeInsets.only(top: Spacing.md),
                child: InfoBanner(
                  icon: Icons.warning_amber_rounded,
                  tone: Tone.warn,
                  text: l.settingsCleartextLong,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.settingsCancel)),
        TextButton(onPressed: _submit, child: Text(l.settingsSave)),
      ],
    );
  }
}

/// A flat switch row: title, hint below, switch on the right (48 dp target).
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
    );
  }
}
