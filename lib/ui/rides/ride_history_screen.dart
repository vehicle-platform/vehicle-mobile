import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:vehicle_mobile/models/ride_summary.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/ride_client.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';
import 'package:vehicle_mobile/ui/rides/ride_format.dart';
import 'package:vehicle_mobile/ui/rides/ride_summary_screen.dart';
import 'package:vehicle_mobile/ui/rides/ride_widgets.dart';

typedef RideDateRangePicker = Future<DateTimeRange?> Function(
    BuildContext context, DateTimeRange? initialRange);

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({
    super.key,
    this.settingsStore = const AppSettingsStore(),
    this.client,
    this.dateRangePicker,
  });

  final AppSettingsStore settingsStore;
  final RideClient? client;
  final RideDateRangePicker? dateRangePicker;

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  late final RideClient _client;
  AppSettings? _settings;
  RidesTable? _table;
  String? _error;
  bool _loading = true;
  int _requestId = 0;
  DateTime? _from;
  DateTime? _to;
  List<String> _selected = const [];

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? RideClient();
    _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final settings = await widget.settingsStore.load();
    if (!mounted || requestId != _requestId) return;
    setState(() => _settings = settings);
    if (!settings.isServerConfigured) {
      setState(() {
        _loading = false;
        _table = null;
      });
      return;
    }
    final result = await _client.listRides(
      baseUrl: settings.serverBaseUrl!,
      apiToken: settings.apiToken ?? '',
      from: _from,
      to: _to,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _table = result.data;
        _error = null;
        _selected = _validSelection(result.data!);
      } else {
        _table = null;
        _error = result.message ?? result.outcome.name;
      }
    });
  }

  List<String> _validSelection(RidesTable table) {
    final names = table.columns.map((column) => column.name).toSet();
    final kept =
        _selected.where(names.contains).take(2).toList(growable: false);
    if (kept.isNotEmpty) return kept;
    return table.columns
        .take(2)
        .map((column) => column.name)
        .toList(growable: false);
  }

  Future<void> _pickRange() async {
    final initial = _from != null && _to != null
        ? DateTimeRange(start: _from!, end: _to!)
        : null;
    final picked = await (widget.dateRangePicker ?? _showDateRangePicker)(
        context, initial);
    if (picked == null || !mounted) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    await _load();
  }

  Future<DateTimeRange?> _showDateRangePicker(
      BuildContext context, DateTimeRange? initial) {
    final now = DateTime.now();
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
    );
  }

  Future<void> _clearRange() async {
    setState(() {
      _from = null;
      _to = null;
    });
    await _load();
  }

  void _toggleColumn(String name) {
    setState(() {
      if (_selected.contains(name)) {
        if (_selected.length > 1) {
          _selected =
              _selected.where((value) => value != name).toList(growable: false);
        }
      } else if (_selected.length < 2) {
        _selected = [..._selected, name];
      }
    });
  }

  void _openSummary(String sessionId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RideSummaryScreen(
          sessionId: sessionId,
          settingsStore: widget.settingsStore,
          client: _client,
        ),
      ),
    );
  }

  String _rangeLabel() {
    if (_from == null || _to == null) return 'All rides';
    return '${formatQueryDate(_from!)} – ${formatQueryDate(_to!)} (UTC days)';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride history'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final settings = _settings;
    if (settings == null || (_loading && _table == null && _error == null)) {
      return const RideLoading('Loading rides...');
    }
    if (!settings.isServerConfigured) {
      return const RideMessage(
        icon: Icons.settings_ethernet,
        message:
            'No vehicle-server configured. Set the server URL and API token in Settings.',
      );
    }
    if (_error != null) {
      return Column(
        children: [
          RideCleartextWarning(settings: settings, padding: RideCleartextWarning.screenPadding),
          Expanded(
            child: RideMessage(
              icon: Icons.cloud_off,
              tone: Tone.error,
              message: _error!,
              actionLabel: 'Retry',
              onAction: _load,
            ),
          ),
        ],
      );
    }
    final table = _table;
    if (table == null) {
      return const RideLoading('Loading rides...');
    }
    if (table.rows.isEmpty) {
      return Column(
        children: [
          RideCleartextWarning(settings: settings, padding: RideCleartextWarning.screenPadding),
          _rangeBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(Spacing.xl),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.route_outlined, size: 40),
                  const SizedBox(height: Spacing.md),
                  const Center(child: Text('No rides in this range.')),
                  if (table.skipped > 0) ...[
                    const SizedBox(height: Spacing.sm),
                    Center(
                      child: Text(
                        '${table.skipped} session${table.skipped == 1 ? '' : 's'} without a stored summary skipped.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    final rows = _newestFirst(table.rows);
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        RideCleartextWarning(settings: settings, padding: RideCleartextWarning.screenPadding),
        _rangeBar(),
        _columnChooser(table),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
              itemCount: rows.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _countLine(table);
                return _rideRow(table, rows[index - 1]);
              },
            ),
          ),
        ),
      ],
    );
  }



  Widget _rangeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range, size: 20),
              const SizedBox(width: Spacing.sm),
              Expanded(
                  child: Text(_rangeLabel(),
                      style: Theme.of(context).textTheme.titleSmall)),
            ],
          ),
          Wrap(
            spacing: Spacing.sm,
            children: [
              TextButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: Text(_from == null ? 'Date range' : 'Change range'),
              ),
              if (_from != null)
                TextButton.icon(
                  onPressed: _clearRange,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _columnChooser(RidesTable table) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Columns', trailing: Text('up to two')),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: [
              for (final column in table.columns)
                FilterChip(
                  label: Text(column.name),
                  selected: _selected.contains(column.name),
                  onSelected:
                      !_selected.contains(column.name) && _selected.length >= 2
                          ? null
                          : (_) => _toggleColumn(column.name),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countLine(RidesTable table) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${table.rows.length} ride${table.rows.length == 1 ? '' : 's'}',
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (table.skipped > 0)
            Text(
              '${table.skipped} skipped',
              style: theme.textTheme.bodySmall!
                  .copyWith(color: context.vehicle.warning),
            ),
        ],
      ),
    );
  }

  Widget _rideRow(RidesTable table, RideRow row) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: SectionCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => _openSummary(row.sessionId),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.createdUtc == null
                      ? 'unknown time'
                      : formatUtc(row.createdUtc!),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: Spacing.xs),
                Text(row.sessionId, style: theme.textTheme.bodySmall),
                for (final name in _selected) _valueLine(table, row, name),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _valueLine(RidesTable table, RideRow row, String name) {
    final index = table.columns.indexWhere((column) => column.name == name);
    if (index < 0) return const SizedBox.shrink();
    final column = table.columns[index];
    final value = row.values[name];
    final flag = row.flags[name];
    final range = _observedRange(table, name);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Spacing.md,
            runSpacing: Spacing.xs,
            children: [
              Text(column.name, style: theme.textTheme.bodyMedium),
              Text(
                '${formatRideValue(value, range.min, range.max)} ${column.unit}',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          if (flag != null)
            Text(
              flag,
              style: theme.textTheme.bodySmall!
                  .copyWith(color: context.vehicle.warning),
            ),
        ],
      ),
    );
  }

  RideRange _observedRange(RidesTable table, String name) {
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (final row in table.rows) {
      final value = row.values[name];
      if (value == null || !value.isFinite) continue;
      min = math.min(min, value);
      max = math.max(max, value);
    }
    if (min == double.infinity) return const RideRange(0, 0);
    return RideRange(min, max);
  }

  List<RideRow> _newestFirst(List<RideRow> rows) {
    final sorted = List<RideRow>.of(rows);
    sorted.sort((a, b) {
      final first = a.createdUtc;
      final second = b.createdUtc;
      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;
      return second.compareTo(first);
    });
    return sorted;
  }
}
