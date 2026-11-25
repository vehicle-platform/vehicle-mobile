import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/host.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/auth_client.dart';
import 'package:vehicle_mobile/services/auth_store.dart';
import 'package:vehicle_mobile/services/token_guard.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';

/// Localized text of a failed account call; never contains the password.
String authFailureText(AppLocalizations l, AuthResult result) {
  switch (result.outcome) {
    case AuthOutcome.ok:
      return '';
    case AuthOutcome.unauthorized:
      return l.settingsAuthBadCredentials;
    case AuthOutcome.forbidden:
      return l.settingsClaimInvalid;
    case AuthOutcome.conflict:
      return l.settingsAuthUsernameTaken;
    case AuthOutcome.invalid:
      return l
          .settingsAuthInvalid(result.message ?? l.settingsAuthInvalidFallback);
    case AuthOutcome.rateLimited:
      final wait = result.retryAfterSeconds;
      return wait == null
          ? l.settingsRateLimited
          : l.settingsRateLimitedWait(wait);
    case AuthOutcome.notSupported:
      return l.settingsAuthNotSupported;
    case AuthOutcome.unreachable:
      return l.settingsUnreachable;
    case AuthOutcome.failed:
      return l
          .settingsAuthRequestFailed(result.message ?? l.settingsUnknownError);
  }
}

/// Login and registration against the active host (D-122). A manual device
/// token stays available under "Advanced".
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.store = const AppSettingsStore(),
    this.client,
    this.message,
    this.onSkip,
  });

  final AppSettingsStore store;
  final AuthClient? client;

  /// Why the rider is here (e.g. the session ended).
  final String? message;

  /// Phone only: continue without a server (BLE and recording need none).
  final VoidCallback? onSkip;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthClient _client = widget.client ?? AuthClient();
  late final AuthStore _auth = AuthStore(widget.store.hosts);
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _vehicleId = TextEditingController();
  final _claimCode = TextEditingController();
  final _deviceToken = TextEditingController();
  List<Host> _hosts = const [];
  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    try {
      final hosts = await widget.store.hosts.load();
      if (!mounted) return;
      setState(() {
        _hosts = hosts;
        // The web build comes with its own origin as the first host.
        if (_url.text.isEmpty && hosts.isNotEmpty) {
          _url.text = hosts.first.baseUrl;
        }
      });
    } catch (_) {
      // No saved hosts: the rider types the URL.
    }
  }

  @override
  void dispose() {
    for (final c in [
      _url,
      _username,
      _password,
      _vehicleId,
      _claimCode,
      _deviceToken
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validUrl() {
    final l = context.l10n;
    final url = _url.text.trim();
    if (url.isEmpty) return l.settingsLoginEnterUrl;
    final refusal = tokenSendRefusal(url);
    if (refusal != null) return l.settingsLoginInsecureUrl;
    return null;
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final urlError = _validUrl();
    if (urlError != null) return setState(() => _error = urlError);
    final user = _username.text.trim();
    final password = _password.text;
    if (user.isEmpty || password.isEmpty) {
      return setState(() => _error = l.settingsLoginNeedCredentials);
    }
    if (_registering &&
        (_vehicleId.text.trim().isEmpty || _claimCode.text.trim().isEmpty)) {
      return setState(() => _error = l.settingsLoginNeedVehicle);
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final baseUrl = _url.text.trim();
    final result = _registering
        ? await _client.register(
            baseUrl: baseUrl,
            username: user,
            password: password,
            vehicleId: _vehicleId.text.trim(),
            claimCode: _claimCode.text.trim())
        : await _client.login(
            baseUrl: baseUrl, username: user, password: password);
    if (!mounted) return;
    if (result.isSuccess && result.session != null) {
      final host = await _auth.ensureHost(baseUrl);
      await _auth.saveSession(host.id, result.session!);
      _password.clear();
      if (mounted) setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _error = authFailureText(l, result);
    });
  }

  Future<void> _useDeviceToken() async {
    final l = context.l10n;
    final urlError = _validUrl();
    if (urlError != null) return setState(() => _error = urlError);
    final token = _deviceToken.text.trim();
    if (token.isEmpty) return setState(() => _error = l.settingsLoginNeedToken);
    final host = await _auth.ensureHost(_url.text.trim());
    await _auth.saveDeviceToken(host.id, token);
    _deviceToken.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    final l = context.l10n;
    final message = _error ?? widget.message;
    final title =
        _registering ? l.settingsLoginRegister : l.settingsLoginSignIn;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.lg),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 2,
                      width: Spacing.xxl,
                      color: t.accent,
                      margin: const EdgeInsets.only(bottom: Spacing.lg),
                    ),
                    Text(title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: Spacing.xs),
                    Text(
                        _registering
                            ? l.settingsLoginSubRegister
                            : l.settingsLoginSubSignIn,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: Spacing.lg),
                    if (message != null) ...[
                      InfoBanner(
                        icon: Icons.info_outline,
                        tone: _error != null ? Tone.error : Tone.warn,
                        text: message,
                      ),
                      const SizedBox(height: Spacing.md),
                    ],
                    if (_hosts.length > 1) ...[
                      DropdownButtonFormField<String>(
                        key: const ValueKey('host-picker'),
                        initialValue: _hosts.any((h) => h.baseUrl == _url.text)
                            ? _url.text
                            : null,
                        decoration: InputDecoration(
                            labelText: l.settingsLoginSavedHost),
                        items: [
                          for (final h in _hosts)
                            DropdownMenuItem(
                                value: h.baseUrl, child: Text(h.name)),
                        ],
                        onChanged: (v) =>
                            setState(() => _url.text = v ?? _url.text),
                      ),
                      const SizedBox(height: Spacing.md),
                    ],
                    TextField(
                      key: const ValueKey('server-url'),
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                          labelText: l.settingsLoginServer,
                          hintText: 'https://vehicle-server.example.com'),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      key: const ValueKey('username'),
                      controller: _username,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration:
                          InputDecoration(labelText: l.settingsLoginUsername),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      key: const ValueKey('password'),
                      controller: _password,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: [
                        _registering
                            ? AutofillHints.newPassword
                            : AutofillHints.password
                      ],
                      textInputAction: _registering
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onSubmitted: _registering ? null : (_) => _submit(),
                      decoration:
                          InputDecoration(labelText: l.settingsLoginPassword),
                    ),
                    if (_registering) ...[
                      const SizedBox(height: Spacing.md),
                      TextField(
                        key: const ValueKey('vehicle-id'),
                        controller: _vehicleId,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        decoration:
                            InputDecoration(labelText: l.settingsVehicleId),
                      ),
                      const SizedBox(height: Spacing.md),
                      TextField(
                        key: const ValueKey('claim-code'),
                        controller: _claimCode,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration:
                            InputDecoration(labelText: l.settingsClaimCode),
                      ),
                    ],
                    const SizedBox(height: Spacing.lg),
                    FilledButton(
                      key: const ValueKey('submit'),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: IconSizes.inline,
                              height: IconSizes.inline,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(title),
                    ),
                    const SizedBox(height: Spacing.sm),
                    TextButton(
                      key: const ValueKey('toggle-mode'),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _registering = !_registering;
                                _error = null;
                              }),
                      child: Text(_registering
                          ? l.settingsLoginHaveAccount
                          : l.settingsLoginRegister),
                    ),
                    Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: const ValueKey('advanced'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(l.settingsLoginAdvanced,
                            style: theme.textTheme.bodyMedium),
                        childrenPadding:
                            const EdgeInsets.only(bottom: Spacing.md),
                        children: [
                          TextField(
                            key: const ValueKey('device-token'),
                            controller: _deviceToken,
                            obscureText: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration:
                                InputDecoration(labelText: l.settingsHostToken),
                          ),
                          const SizedBox(height: Spacing.md),
                          OutlinedButton(
                            key: const ValueKey('connect-token'),
                            onPressed: _useDeviceToken,
                            child: Text(l.settingsLoginConnect),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onSkip != null)
                      TextButton(
                        key: const ValueKey('skip'),
                        onPressed: widget.onSkip,
                        child: Text(l.settingsLoginSkip),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
