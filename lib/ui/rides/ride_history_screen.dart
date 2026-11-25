import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/ride_summary.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/ride_client.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/shell/shell_scope.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';
import 'package:vehicle_mobile/ui/widgets/readout.dart';
import 'package:vehicle_mobile/ui/rides/ride_format.dart';
import 'package:vehicle_mobile/ui/rides/quantities.dart';
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
    this.onOpenRide,
  });

  final AppSettingsStore settingsStore;
  final RideClient? client;
  final RideDateRangePicker? dateRangePicker;

  /// Wide layout (D-130 item 2): opens the ride in the detail pane instead of
  /// pushing a route.
  final ValueChanged<String>? onOpenRide;

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

  /// Pull-to-refresh, the refresh button and Retry: also probe the host list
  /// again (D-121 item 4).
  Future<void> _refresh() => _load(reprobe: true);

  Future<void> _load({bool reprobe = false}) async {
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final settings = await widget.settingsStore.load(reprobe: reprobe);
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
    return _selected
        .where((name) => names.contains(name) && !logbookBaseColumns.contains(name))
        .take(2)
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
        _selected =
            _selected.where((value) => value != name).toList(growable: false);
      } else if (_selected.length < 2) {
        _selected = [..._selected, name];
      }
    });
  }

  void _openSummary(String sessionId) {
    final onOpen = widget.onOpenRide;
    if (onOpen != null) {
      onOpen(sessionId);
      return;
    }
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
    final l = context.l10n;
    if (_from == null || _to == null) return l.logbookAllRides;
    return l.logbookRangeUtc(formatQueryDate(_from!), formatQueryDate(_to!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navLogbook),
        actions: [
          const HeaderActions(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.logbookRefresh,
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: ContentColumn(child: _body()),
    );
  }

  Widget _body() {
    final settings = _settings;
    if (settings == null || (_loading && _table == null && _error == null)) {
      return RideLoading(context.l10n.logbookLoadingRides);
    }
    if (!settings.isServerConfigured) {
      return RideMessage(
        icon: Icons.settings_ethernet,
        message: context.l10n.logbookNoServer,
      );
    }
    if (_error != null) {
      return Column(
        children: [
          RideCleartextWarning(
              settings: settings, padding: RideCleartextWarning.screenPadding),
          Expanded(
            child: RideMessage(
              icon: Icons.cloud_off,
              tone: Tone.error,
              message: _error!,
              actionLabel: context.l10n.logbookRetry,
              onAction: _refresh,
            ),
          ),
        ],
      );
    }
    final table = _table;
    if (table == null) {
      return RideLoading(context.l10n.logbookLoadingRides);
    }
    if (table.rows.isEmpty) {
      return Column(
        children: [
          RideCleartextWarning(
              settings: settings, padding: RideCleartextWarning.screenPadding),
          _rangeBar(table),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: EmptyState(
                      icon: Icons.route_outlined,
                      message: context.l10n.logbookNoRidesInRange,
                      hint: table.skipped > 0
                          ? context.l10n.logbookSkippedHint(table.skipped)
                          : null,
                    ),
                  ),
                ),
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
        RideCleartextWarning(
            settings: settings, padding: RideCleartextWarning.screenPadding),
        _rangeBar(table),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: Spacing.xl),
              itemCount: rows.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
                    child: _countLine(table),
                  );
                }
                return _rideRow(table, rows[index - 1]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _rangeBar(RidesTable table) {
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
                label: Text(_from == null
                    ? context.l10n.logbookDateRange
                    : context.l10n.logbookChangeRange),
              ),
              if (_from != null)
                TextButton.icon(
                  onPressed: _clearRange,
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(context.l10n.logbookClear),
                ),
              TextButton.icon(
                onPressed: () => _openCompare(table),
                icon: const Icon(Icons.compare_arrows, size: 18),
                label: Text(_selected.isEmpty
                    ? context.l10n.logbookCompare
                    : '${context.l10n.logbookCompare} (${_selected.length})'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The compare picker (D-130 follow-up): up to two extra quantities per
  /// ride. Rider quantities first; engineering signals under "All signals".
  Future<void> _openCompare(RidesTable table) {
    final l = context.l10n;
    final names = table.columns.map((c) => c.name).toList(growable: false);
    final rider = [
      for (final n in riderQuantityOrder)
        if (names.contains(n) && !logbookBaseColumns.contains(n)) n,
    ];
    final engineering = [
      for (final n in names)
        if (!rider.contains(n) && !logbookBaseColumns.contains(n)) n,
    ];
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Widget chips(List<String> list) => Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.xs,
                children: [
                  for (final name in list)
                    FilterChip(
                      label: Text(quantityText(l, name)),
                      selected: _selected.contains(name),
                      onSelected: !_selected.contains(name) &&
                              _selected.length >= 2
                          ? null
                          : (_) {
                              _toggleColumn(name);
                              setSheetState(() {});
                            },
                    ),
                ],
              );
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.8),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, 0, Spacing.lg, Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.logbookCompareTitle,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: Spacing.xs),
                    Text(l.logbookCompareHint,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: Spacing.lg),
                    if (rider.isNotEmpty) ...[
                      SectionLabel(l.logbookRiderQuantities),
                      chips(rider),
                    ],
                    if (engineering.isNotEmpty)
                      Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(l.logbookAllSignals,
                              style: Theme.of(context).textTheme.titleSmall),
                          childrenPadding:
                              const EdgeInsets.only(bottom: Spacing.md),
                          expandedAlignment: Alignment.centerLeft,
                          children: [chips(engineering)],
                        ),
                      ),
                    const SizedBox(height: Spacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: Text(l.logbookCompareDone),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
              context.l10n.logbookRideCount(table.rows.length),
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (table.skipped > 0)
            Text(
              context.l10n.logbookSkippedCount(table.skipped),
              style: theme.textTheme.bodySmall!
                  .copyWith(color: context.vehicle.advisory),
            ),
        ],
      ),
    );
  }

  Widget _rideRow(RidesTable table, RideRow row) {
    final t = context.vehicle;
    final shown = [
      for (final name in logbookBaseColumns)
        if (table.columns.any((c) => c.name == name)) name,
      ..._selected,
    ];
    final readouts = [
      for (final name in shown) _valueReadout(table, row, name),
    ].whereType<Widget>().toList(growable: false);
    return DecoratedBox(
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: t.hairline))),
      child: InkWell(
        onTap: () => _openSummary(row.sessionId),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.createdUtc == null
                    ? context.l10n.logbookUnknownTime
                    : formatUtc(row.createdUtc!),
                style: numberFace(20, FontWeight.w600, color: t.textPrimary),
              ),
              if (readouts.isNotEmpty) ...[
                const SizedBox(height: Spacing.md),
                Wrap(
                  spacing: Spacing.xl,
                  runSpacing: Spacing.md,
                  children: readouts,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget? _valueReadout(RidesTable table, RideRow row, String name) {
    final index = table.columns.indexWhere((column) => column.name == name);
    if (index < 0) return null;
    final column = table.columns[index];
    final value = row.values[name];
    final flag = row.flags[name];
    final range = _observedRange(table, name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Readout(
          label: quantityText(context.l10n, column.name),
          value: column.unit == 's' || column.unit == 'count'
              ? formatQuantity(value, column.unit)
              : formatRideValue(value, range.min, range.max),
          unit: quantityUnit(column.unit),
          size: ReadoutSize.small,
        ),
        if (flag != null)
          Text(
            flag,
            style: Theme.of(context)
                .textTheme
                .bodySmall!
                .copyWith(color: context.vehicle.advisory),
          ),
      ],
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
