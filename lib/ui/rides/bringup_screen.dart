import 'package:flutter/material.dart';

import '../../models/bringup_result.dart';
import '../../services/app_settings.dart';
import '../../services/ride_client.dart';
import '../settings_screen.dart';
import '../telemetry/link_status.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'ride_widgets.dart';

/// Read-only server bring-up gate answer for one stored session.
///
/// The screen only renders `GET /sessions/{id}/bringup`: the verdict, checks,
/// manual items and warnings are the server's answer, never re-derived here.
class BringupScreen extends StatefulWidget {
  const BringupScreen({
    super.key,
    required this.sessionId,
    this.settingsStore = const AppSettingsStore(),
    this.client,
  });

  final String sessionId;
  final AppSettingsStore settingsStore;
  final RideClient? client;

  @override
  State<BringupScreen> createState() => _BringupScreenState();
}

class _BringupScreenState extends State<BringupScreen> {
  static const String _defaultGate = 'V0';
  static const List<String> _gates = ['B0', 'V0', 'V1'];

  late final RideClient _client;
  AppSettings? _settings;
  BringupResult? _result;
  RideOutcome? _outcome;
  String? _error;
  String _gate = _defaultGate;
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? RideClient();
    _load();
  }

  bool _isConfigured(AppSettings settings) =>
      settings.isServerConfigured && (settings.apiToken?.isNotEmpty ?? false);

  Future<void> _load({bool reloadSettings = false}) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _outcome = null;
      _result = null;
    });

    AppSettings settings;
    try {
      settings = (reloadSettings || _settings == null)
          ? await widget.settingsStore.load()
          : _settings!;
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _settings = const AppSettings();
        _loading = false;
        _error = 'Could not read the server settings: $error';
      });
      return;
    }
    if (!mounted || requestId != _requestId) return;
    setState(() => _settings = settings);
    if (!_isConfigured(settings)) {
      setState(() => _loading = false);
      return;
    }

    final result = await _client.getBringup(
      baseUrl: settings.serverBaseUrl!,
      apiToken: settings.apiToken!,
      sessionId: widget.sessionId,
      gate: _gate,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _result = result.data;
      } else {
        _outcome = result.outcome;
        _error = _errorText(result);
      }
    });
  }

  String _errorText(RideResult<BringupResult> result) {
    return switch (result.outcome) {
      RideOutcome.unsupported =>
        'this server has no bring-up check (needs vehicle-server with the bring-up route, server#50)',
      RideOutcome.unauthorized =>
        'Unauthorized: check the API token in Settings.',
      RideOutcome.notFound =>
        'the server does not have this session (upload it first)',
      RideOutcome.invalid => result.message ?? 'invalid request',
      RideOutcome.unavailable => result.message ?? 'server unavailable',
      RideOutcome.failed => result.message ?? 'request failed',
      RideOutcome.ok => '',
    };
  }

  void _selectGate(String gate) {
    if (gate == _gate) return;
    setState(() => _gate = gate);
    _load();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(store: widget.settingsStore)),
    );
    if (mounted) await _load(reloadSettings: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bring-up check'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('SESSION', style: theme.textTheme.labelSmall),
                  const SizedBox(height: Spacing.xs),
                  Text(widget.sessionId, style: theme.textTheme.titleSmall),
                  const SizedBox(height: Spacing.md),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      for (final gate in _gates)
                        ButtonSegment<String>(value: gate, label: Text(gate)),
                    ],
                    selected: {_gate},
                    onSelectionChanged: (selection) =>
                        _selectGate(selection.first),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _body(settings)),
        ],
      ),
    );
  }

  Widget _body(AppSettings? settings) {
    if (settings == null || _loading) {
      return const RideLoading('Loading bring-up check...');
    }
    if (!_isConfigured(settings)) {
      return RideMessage(
        icon: Icons.settings_ethernet,
        message:
            'No vehicle-server configured. Set the server URL and API token in Settings.',
        actionLabel: 'Open Settings',
        onAction: _openSettings,
      );
    }
    if (_error != null) {
      final settingsAction = _outcome == RideOutcome.unauthorized;
      return Column(
        children: [
          RideCleartextWarning(
              settings: settings, padding: RideCleartextWarning.screenPadding),
          Expanded(
            child: RideMessage(
              icon: _outcome == RideOutcome.notFound
                  ? Icons.search_off
                  : Icons.cloud_off,
              tone: _outcome == RideOutcome.unauthorized ||
                      _outcome == RideOutcome.notFound
                  ? Tone.neutral
                  : Tone.error,
              message: _error!,
              actionLabel: settingsAction ? 'Open Settings' : 'Retry',
              onAction: settingsAction ? _openSettings : _load,
            ),
          ),
        ],
      );
    }
    if (_result == null) {
      return RideMessage(
        icon: Icons.help_outline,
        message: 'The server returned no bring-up answer.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    return _content(settings, _result!);
  }

  Widget _content(AppSettings settings, BringupResult result) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
        children: [
          if (settings.sendsTokenInCleartext)
            RideCleartextWarning(settings: settings),
          _verdict(result),
          const SizedBox(height: Spacing.lg),
          const SectionLabel('Checks'),
          if (result.checks.isEmpty)
            const SectionCard(
                child: Text('The server returned no checks for this gate.'))
          else
            for (final check in result.checks) _checkCard(check),
        ],
      ),
    );
  }

  Widget _verdict(BringupResult result) {
    final pending = result.needsYou.length;
    final warnings = result.warnings.length;
    final style = _statusStyle(result.verdict);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(icon: style.icon, label: result.verdict, tone: style.tone),
          if (pending > 0) ...[
            const SizedBox(height: Spacing.sm),
            Text('$pending manual check${pending == 1 ? '' : 's'} pending'),
          ],
          if (warnings > 0) ...[
            const SizedBox(height: Spacing.xs),
            Text(
              '$warnings warning${warnings == 1 ? '' : 's'}',
              style: TextStyle(color: context.vehicle.warning),
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Text(
            'manual: you judge this one at the bike (V1 throttle blip, B0 at rest). '
            'unknown: the session has no data for it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _checkCard(BringupCheck check) {
    final theme = Theme.of(context);
    final style = _statusStyle(check.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(
                    icon: style.icon, label: check.status, tone: style.tone),
                const SizedBox(width: Spacing.md),
                Expanded(
                    child: Text(check.id, style: theme.textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: Spacing.md),
            _field('Measured', formatBringupMeasured(check.measured)),
            _field('Expected', check.expected),
            _field('Source', check.source),
            if (check.note.isNotEmpty) _field('Note', check.note),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
          const SizedBox(height: Spacing.xs),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.tone, this.icon);

  final Tone tone;
  final IconData icon;
}

_StatusStyle _statusStyle(String status) {
  return switch (status) {
    'pass' => const _StatusStyle(Tone.ok, Icons.check_circle_outline),
    'fail' => const _StatusStyle(Tone.error, Icons.cancel_outlined),
    'warn' => const _StatusStyle(Tone.warn, Icons.warning_amber_rounded),
    'manual' => const _StatusStyle(Tone.accent, Icons.touch_app_outlined),
    _ => const _StatusStyle(Tone.neutral, Icons.help_outline),
  };
}

/// Compact, readable text of one server measured value.
///
/// Objects become one `key: value` line per entry; lists are joined. Nested
/// objects inside a value stay on that line. Nothing is rounded or recomputed.
String formatBringupMeasured(Object? value) {
  if (value == null) return '—';
  if (value is Map) {
    if (value.isEmpty) return '{}';
    return value.entries
        .map((entry) => '${entry.key}: ${_inlineMeasured(entry.value)}')
        .join('\n');
  }
  if (value is List) {
    if (value.isEmpty) return '[]';
    return value.map(_inlineMeasured).join(', ');
  }
  return _scalarMeasured(value);
}

String _inlineMeasured(Object? value) {
  if (value is List) {
    if (value.isEmpty) return '[]';
    return value.map(_inlineMeasured).join(', ');
  }
  if (value is Map) {
    if (value.isEmpty) return '{}';
    return value.entries
        .map((entry) => '${entry.key}: ${_inlineMeasured(entry.value)}')
        .join(', ');
  }
  return _scalarMeasured(value);
}

String _scalarMeasured(Object? value) {
  if (value == null) return '—';
  return value.toString();
}
