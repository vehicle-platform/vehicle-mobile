import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/bringup_result.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/ride_client.dart';
import 'package:vehicle_mobile/ui/settings_screen.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';
import 'package:vehicle_mobile/ui/rides/ride_widgets.dart';

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
  bool _settingsFailed = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? RideClient();
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first load reads localized fallback texts, so it starts here.
    if (_started) return;
    _started = true;
    _load();
  }

  bool _isConfigured(AppSettings settings) =>
      settings.isServerConfigured && (settings.apiToken?.isNotEmpty ?? false);

  /// Loads the answer. The previous result stays visible while refreshing;
  /// pass [clearResult] when it no longer applies (gate or settings change).
  Future<void> _load({
    bool reloadSettings = false,
    bool clearResult = false,
  }) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _outcome = null;
      _settingsFailed = false;
      if (clearResult) _result = null;
    });

    final settingsFailedText = context.l10n.logbookSettingsReadFailed;
    final errorTexts = _errorTexts(context);
    AppSettings settings;
    try {
      settings = (reloadSettings || _settings == null)
          ? await widget.settingsStore.load()
          : _settings!;
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _settings = const AppSettings();
        _loading = false;
        _result = null;
        _settingsFailed = true;
        _error = settingsFailedText;
      });
      return;
    }
    if (!mounted || requestId != _requestId) return;
    setState(() => _settings = settings);
    if (!_isConfigured(settings)) {
      setState(() {
        _loading = false;
        _result = null;
      });
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
        _result = null;
        _outcome = result.outcome;
        _error = _errorText(result, errorTexts);
      }
    });
  }

  _ErrorTexts _errorTexts(BuildContext context) {
    final l = context.l10n;
    return _ErrorTexts(
      unsupported: l.logbookBringupUnsupported,
      unauthorized: l.logbookBringupUnauthorized,
      notFound: l.logbookBringupNotFound,
      invalid: l.logbookBringupInvalid,
      unavailable: l.logbookBringupUnavailable,
      failed: l.logbookBringupFailed,
    );
  }

  String _errorText(RideResult<BringupResult> result, _ErrorTexts texts) {
    return switch (result.outcome) {
      RideOutcome.unsupported => texts.unsupported,
      RideOutcome.unauthorized => texts.unauthorized,
      RideOutcome.notFound => [
          texts.notFound,
          // ride_client falls back to the literal "not found" without a server detail.
          if (result.message != null &&
              result.message!.trim().isNotEmpty &&
              result.message!.trim().toLowerCase() != 'not found')
            result.message!.trim(),
        ].join(': '),
      RideOutcome.invalid => result.message ?? texts.invalid,
      RideOutcome.unavailable => result.message ?? texts.unavailable,
      RideOutcome.failed => result.message ?? texts.failed,
      RideOutcome.ok => '',
    };
  }

  void _selectGate(String gate) {
    if (gate == _gate) return;
    setState(() {
      _gate = gate;
      _result = null;
    });
    _load(clearResult: true);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(store: widget.settingsStore)),
    );
    if (mounted) await _load(reloadSettings: true, clearResult: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.logbookBringupTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.logbookRefresh,
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
                  Text(upperFor(context, context.l10n.logbookSession),
                      style: theme.textTheme.labelSmall),
                  const SizedBox(height: Spacing.xs),
                  Text(widget.sessionId,
                      style: numberFace(20, FontWeight.w600,
                          color: context.vehicle.textPrimary)),
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
    if (settings == null || (_loading && _result == null)) {
      return RideLoading(context.l10n.logbookLoadingBringup);
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
              actionLabel: settingsAction
                  ? context.l10n.logbookOpenSettings
                  : context.l10n.logbookRetry,
              onAction: settingsAction
                  ? _openSettings
                  : () => _load(reloadSettings: _settingsFailed),
            ),
          ),
        ],
      );
    }
    if (!_isConfigured(settings)) {
      return RideMessage(
        icon: Icons.settings_ethernet,
        message: context.l10n.logbookNoServer,
        actionLabel: context.l10n.logbookOpenSettings,
        onAction: _openSettings,
      );
    }
    if (_result == null) {
      return RideMessage(
        icon: Icons.help_outline,
        message: context.l10n.logbookNoBringupAnswer,
        actionLabel: context.l10n.logbookRetry,
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
          SectionLabel(context.l10n.logbookChecks),
          if (result.checks.isEmpty)
            SectionCard(child: Text(context.l10n.logbookNoChecks))
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
          StatusPill(
            key: const ValueKey('bringup-verdict'),
            icon: style.icon,
            label: result.verdict,
            tone: style.tone,
          ),
          if (pending > 0) ...[
            const SizedBox(height: Spacing.sm),
            Text(context.l10n
                .logbookManualPending(pending, result.needsYou.join(', '))),
          ],
          if (warnings > 0) ...[
            const SizedBox(height: Spacing.xs),
            Text(
              context.l10n
                  .logbookWarningsList(warnings, result.warnings.join(', ')),
              style: TextStyle(color: context.vehicle.advisory),
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Text(
            context.l10n.logbookBringupLegend,
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
        key: ValueKey('bringup-check-${check.id}'),
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
            _field(context.l10n.logbookMeasured,
                formatBringupMeasured(check.measured)),
            _field(context.l10n.logbookExpected, check.expected),
            _field(context.l10n.logbookSource, check.source),
            if (check.note.isNotEmpty)
              _field(context.l10n.logbookNote, check.note),
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
          Text(upperFor(context, label), style: theme.textTheme.labelSmall),
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

/// The localized fallback texts of a failed bring-up request, read before the
/// request starts so no context is used across the async gap.
class _ErrorTexts {
  const _ErrorTexts({
    required this.unsupported,
    required this.unauthorized,
    required this.notFound,
    required this.invalid,
    required this.unavailable,
    required this.failed,
  });

  final String unsupported;
  final String unauthorized;
  final String notFound;
  final String invalid;
  final String unavailable;
  final String failed;
}
