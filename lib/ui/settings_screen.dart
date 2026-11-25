import 'package:flutter/material.dart';

import 'package:vehicle_mobile/models/host.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/auth_client.dart';
import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:vehicle_mobile/services/auth_store.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/services/token_guard.dart';
import 'package:vehicle_mobile/services/voice/voice_settings.dart';
import 'package:vehicle_mobile/ui/notifications/notification_scope.dart';
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
      this.authClient});

  final AppSettingsStore store;

  /// Account calls (logout, claim a vehicle); a default client when null.
  final AuthClient? authClient;

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
        title: const Text('Delete host?'),
        content: Text(
            'Removes "${host.name}" and its device token from this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
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
            id, AccountInfo(username: current.username, vehicles: result.vehicles!));
      }
      setState(() => _accountMessage = null);
      await _load();
    } else {
      setState(() => _accountMessage =
          authFailureTextForClaim(result));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
                  SectionLabel(
                    'Hosts (vehicle-server)',
                    trailing: IconButton(
                      tooltip: 'Add host',
                      icon: const Icon(Icons.add),
                      onPressed: () => _addOrEdit(),
                    ),
                  ),
                  if (_loadFailed)
                    const Padding(
                      padding: EdgeInsets.only(bottom: Spacing.md),
                      child: InfoBanner(
                        icon: Icons.error_outline,
                        tone: Tone.error,
                        text: 'Could not read the saved hosts.',
                      ),
                    ),
                  if (_hosts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: Text(
                        'No host configured yet: recording and sharing sessions work fully without '
                        'one. Add a host to enable upload, rides, faults and the assistant.',
                        style: theme.textTheme.bodySmall!
                            .copyWith(color: t.textSecondary),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Text(
                        'The first host that answers is used, so put the local one first. '
                        'Drag to reorder.',
                        style: theme.textTheme.bodySmall!
                            .copyWith(color: t.textSecondary),
                      ),
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
                          label: Text(
                              _checking ? 'Checking...' : 'Check hosts again'),
                        ),
                      ),
                  ],
                  const SizedBox(height: Spacing.lg),
                  const SectionLabel('Upload'),
                  SectionCard(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Upload only on Wi-Fi',
                          style: theme.textTheme.titleSmall),
                      subtitle: Text(
                        'Session archives can be several MB; avoid mobile data by default.',
                        style: theme.textTheme.bodySmall,
                      ),
                      value: _uploadOnlyOnWifi,
                      onChanged: _setWifiOnly,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  const SectionLabel('Sürüş Asistanı'),
                  SectionCard(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Cevapları sesli oku',
                          style: theme.textTheme.titleSmall),
                      subtitle: Text(
                        'Sürüş Asistanı cevabın metnini sesli okur. Telefonda varsayılan açık, web ve bilgisayarda kapalı.',
                        style: theme.textTheme.bodySmall,
                      ),
                      value: _readAnswers,
                      onChanged: _setReadAnswers,
                    ),
                  ),
                ],
              ),
            ),
            ),
    );
  }

  Widget _accountSection(BuildContext context) {
    final theme = Theme.of(context);
    final account = _account;
    final children = <Widget>[];
    if (account != null) {
      children.add(Text('Giriş yapan: ${account.username}',
          style: theme.textTheme.titleSmall));
      if (account.vehicles.isEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: Spacing.xs),
          child: Text('Bu hesaba bağlı araç yok.', style: theme.textTheme.bodySmall),
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
      children.add(Text("Cihaz token'ı ile bağlı", style: theme.textTheme.titleSmall));
    } else {
      children.add(Text('Giriş yapılmadı', style: theme.textTheme.titleSmall));
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
            label: const Text('Araç ekle'),
          ),
        if (_hasSession)
          OutlinedButton.icon(
            key: const ValueKey('logout'),
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış yap'),
          )
        else
          FilledButton(
            key: const ValueKey('request-login'),
            onPressed: () => AuthEvents.emit(AuthEvent.loginRequested),
            child: const Text('Giriş yap'),
          ),
      ],
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Hesap'),
        SectionCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ],
    );
  }
}

/// Text of a failed vehicle claim.
String authFailureTextForClaim(AuthResult result) => switch (result.outcome) {
      AuthOutcome.forbidden => 'Araç kimliği veya kod geçersiz.',
      AuthOutcome.rateLimited => 'Çok fazla deneme. Biraz sonra tekrar dene.',
      AuthOutcome.unreachable => 'Sunucuya ulaşılamadı.',
      AuthOutcome.unauthorized => 'Oturum sona erdi.',
      _ => 'Araç eklenemedi: ${result.message ?? 'bilinmeyen hata'}',
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
    return AlertDialog(
      title: const Text('Araç ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _vehicleId,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Araç kimliği'),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _code,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Talep kodu'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        TextButton(
          onPressed: () {
            final id = _vehicleId.text.trim();
            final code = _code.text.trim();
            if (id.isEmpty || code.isEmpty) return;
            Navigator.pop(context, (id, code));
          },
          child: const Text('Ekle'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.sm, Spacing.sm, Spacing.sm),
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
                        const StatusPill(
                            icon: Icons.check_circle,
                            label: 'active',
                            tone: Tone.ok),
                    ],
                  ),
                  Text(host.baseUrl, style: theme.textTheme.bodySmall),
                  Text(hasToken ? 'token set' : 'no token',
                      style: theme.textTheme.bodySmall),
                  if (isCleartextRemoteUrl(host.baseUrl))
                    const Padding(
                      padding: EdgeInsets.only(top: Spacing.xs),
                      child: InfoBanner(
                        icon: Icons.warning_amber_rounded,
                        tone: Tone.warn,
                        text:
                            'http:// sends the token and ride data unencrypted. Use it only on a '
                            'trusted local network.',
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
                tooltip: 'Edit host',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit),
            IconButton(
                tooltip: 'Delete host',
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
    final name = _name.text.trim();
    final url = _url.text.trim();
    final nameError = name.isEmpty ? 'Enter a name' : null;
    final refusal = tokenSendRefusal(url);
    final urlError = url.isEmpty
        ? 'Enter the server URL'
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
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add host' : 'Edit host'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Bike (local Raspi)',
                  errorText: _nameError),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Server base URL',
                hintText: 'https://vehicle-server.example.com',
                errorText: _urlError,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _token,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Device token'),
            ),
            if (isCleartextRemoteUrl(_url.text))
              const Padding(
                padding: EdgeInsets.only(top: Spacing.md),
                child: InfoBanner(
                  icon: Icons.warning_amber_rounded,
                  tone: Tone.warn,
                  text:
                      'Warning: http:// sends the token and ride data unencrypted. Use it only '
                      'on a trusted local network; use https:// for any server reachable from outside.',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
