import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/auth_client.dart';
import 'package:vehicle_mobile/services/auth_events.dart';
import 'package:vehicle_mobile/services/auth_store.dart';
import 'package:vehicle_mobile/ui/auth/login_screen.dart';

/// Shows [builder]'s app once the active host has a token, else the login
/// screen (D-122 item 5). A 401 from any client clears the host's session and
/// returns here with a short message.
///
/// With [allowSkip] (the phone: BLE live view and recording work without any
/// server) the app stays mounted underneath and the login can be dismissed
/// for the session. Without it (web, desktop) the app is rebuilt after every
/// sign-in so no screen keeps a stale answer.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.builder,
    this.store = const AppSettingsStore(),
    this.client,
    this.allowSkip = false,
  });

  final WidgetBuilder builder;
  final AppSettingsStore store;
  final AuthClient? client;
  final bool allowSkip;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _Gate { loading, signedIn, needsLogin }

class _AuthGateState extends State<AuthGate> {
  _Gate _state = _Gate.loading;
  bool _sessionEnded = false;
  bool _skipped = false;
  int _generation = 0;
  StreamSubscription<AuthEvent>? _events;

  @override
  void initState() {
    super.initState();
    _events = AuthEvents.stream.listen(_onEvent);
    _check();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _onEvent(AuthEvent event) async {
    if (event == AuthEvent.unauthorized) {
      await _dropSession();
      if (!mounted) return;
      _skipped = false;
      _sessionEnded = true;
    } else if (event == AuthEvent.loginRequested) {
      _skipped = false;
      _sessionEnded = false;
    } else if (event == AuthEvent.signedIn) {
      _sessionEnded = false;
      if (!widget.allowSkip) _generation++;
    }
    await _check();
  }

  Future<void> _dropSession() async {
    try {
      final settings = await widget.store.load();
      final id = settings.hostId;
      if (id != null && (settings.apiToken ?? '').isNotEmpty) {
        await AuthStore(widget.store.hosts).clearSession(id, event: null);
      }
    } catch (_) {
      // Keystore unavailable: the next check shows the login anyway.
    }
  }

  Future<void> _check() async {
    var signedIn = false;
    try {
      final settings = await widget.store.load();
      signedIn =
          settings.isServerConfigured && (settings.apiToken ?? '').isNotEmpty;
    } catch (_) {
      signedIn = false;
    }
    if (!mounted) return;
    setState(() => _state = signedIn ? _Gate.signedIn : _Gate.needsLogin);
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _Gate.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final showLogin = _state == _Gate.needsLogin && !_skipped;
    final message =
        _sessionEnded ? context.l10n.settingsLoginSessionEnded : null;
    if (showLogin && !widget.allowSkip) {
      return LoginScreen(
          store: widget.store, client: widget.client, message: message);
    }
    final app = KeyedSubtree(
        key: ValueKey(_generation), child: Builder(builder: widget.builder));
    if (!widget.allowSkip) return app;
    // Phone: the app (and a running recording) stays mounted under the login.
    return Stack(
      children: [
        Offstage(offstage: showLogin, child: app),
        if (showLogin)
          LoginScreen(
            store: widget.store,
            client: widget.client,
            message: message,
            onSkip: () => setState(() => _skipped = true),
          ),
      ],
    );
  }
}
