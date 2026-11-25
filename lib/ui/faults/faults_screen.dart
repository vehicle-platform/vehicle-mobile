import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/ride_client.dart';
import 'package:vehicle_mobile/ui/rides/ride_widgets.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/shell/shell_scope.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';

/// Fault catalogue of the vehicle from the active host (`GET /faults`). Texts
/// are the server's (catalogue from vehicle-defs); the app adds no advice.
class FaultsScreen extends StatefulWidget {
  const FaultsScreen(
      {super.key,
      this.settingsStore = const AppSettingsStore(),
      this.client,
      this.embedded = false});

  /// Inside the Garage destination: no scaffold or app bar of its own.
  final bool embedded;

  final AppSettingsStore settingsStore;
  final RideClient? client;

  @override
  State<FaultsScreen> createState() => _FaultsScreenState();
}

class _FaultsScreenState extends State<FaultsScreen> {
  late final RideClient _client;
  AppSettings? _settings;
  List<Map<String, Object?>>? _entries;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? RideClient();
    _load();
  }

  Future<void> _load({bool reprobe = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    AppSettings settings;
    try {
      settings = await widget.settingsStore.load(reprobe: reprobe);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not read the host settings.';
      });
      return;
    }
    if (!mounted) return;
    _settings = settings;
    if (!settings.isServerConfigured || (settings.apiToken ?? '').isEmpty) {
      setState(() {
        _loading = false;
        _entries = null;
      });
      return;
    }
    final result = await _client.listFaults(
        baseUrl: settings.serverBaseUrl!, apiToken: settings.apiToken!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _entries = result.data;
      _error =
          result.isSuccess ? null : (result.message ?? result.outcome.name);
    });
  }

  Future<void> _refresh() => _load(reprobe: true);

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: context.l10n.garageRefresh,
              onPressed: _loading ? null : _refresh,
            ),
          ),
          Expanded(child: ContentColumn(child: _body())),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.garageFaultsTitle),
        actions: [
          const HeaderActions(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.garageRefresh,
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: ContentColumn(child: _body()),
    );
  }

  Widget _body() {
    final l = context.l10n;
    final settings = _settings;
    if (_loading && _entries == null) {
      return RideLoading(l.garageFaultsLoading);
    }
    if (settings != null &&
        (!settings.isServerConfigured || (settings.apiToken ?? '').isEmpty)) {
      return RideMessage(
        icon: Icons.settings_ethernet,
        message: l.garageFaultsNoServer,
      );
    }
    if (_error != null) {
      return RideMessage(
        icon: Icons.cloud_off,
        tone: Tone.error,
        message: _error!,
        actionLabel: l.garageFaultsRetry,
        onAction: _refresh,
      );
    }
    final entries = _entries ?? const [];
    if (entries.isEmpty) {
      return RideMessage(
          icon: Icons.check_circle_outline, message: l.garageFaultsEmpty);
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
        itemCount: entries.length,
        itemBuilder: (_, i) => _FaultTile(entry: entries[i]),
      ),
    );
  }
}

class _FaultTile extends StatelessWidget {
  const _FaultTile({required this.entry});

  final Map<String, Object?> entry;

  String? _text(String key) {
    final value = entry[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// Semantic colour from the entry's own fields: a stop advice or a
  /// high/critical severity is red, a medium/warning one amber, otherwise
  /// neutral. The app adds no classification of its own.
  Color _accent(VehicleTokens t) {
    final severity = _text('severity')?.toLowerCase();
    if (entry['advise_stop'] == true ||
        severity == 'critical' ||
        severity == 'high') {
      return t.critical;
    }
    if (severity == 'warning' || severity == 'medium') return t.advisory;
    return t.noData;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    final id = _text('id') ?? '?';
    final rider = _text('rider_text');
    final cause = _text('root_cause');
    final subsystem = _text('subsystem');
    final accent = _accent(t);
    return DecoratedBox(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: t.hairline))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: accent),
            Expanded(
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(id,
                      style: numberFace(20, FontWeight.w600, color: accent)),
                  subtitle: subsystem == null
                      ? null
                      : Text(upperFor(context, subsystem),
                          style: theme.textTheme.labelSmall),
                  childrenPadding: const EdgeInsets.fromLTRB(
                      Spacing.lg, 0, Spacing.lg, Spacing.md),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cause != null)
                      Text(cause, style: theme.textTheme.bodyMedium),
                    if (rider != null) ...[
                      const SizedBox(height: Spacing.sm),
                      Text(rider, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
