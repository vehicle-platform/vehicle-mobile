import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/l10n/rider_format.dart';
import 'package:vehicle_mobile/models/health_windows.dart';
import 'package:vehicle_mobile/models/ride_mark.dart';
import 'package:vehicle_mobile/models/ride_summary.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/marks_client.dart';
import 'package:vehicle_mobile/services/ride_client.dart';
import 'package:vehicle_mobile/ui/telemetry/link_status.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';
import 'package:vehicle_mobile/ui/widgets/readout.dart';
import 'package:vehicle_mobile/ui/assistant/assistant_screen.dart';
import 'package:vehicle_mobile/ui/rides/bringup_screen.dart';
import 'package:vehicle_mobile/ui/rides/health_windows_section.dart';
import 'package:vehicle_mobile/ui/rides/quantities.dart';
import 'package:vehicle_mobile/ui/rides/ride_format.dart';
import 'package:vehicle_mobile/ui/rides/ride_marks_section.dart';
import 'package:vehicle_mobile/ui/rides/ride_widgets.dart';

class RideSummaryScreen extends StatefulWidget {
  const RideSummaryScreen({
    super.key,
    required this.sessionId,
    this.settingsStore = const AppSettingsStore(),
    this.client,
    this.marksClient,
  });

  final String sessionId;
  final AppSettingsStore settingsStore;
  final RideClient? client;
  final MarksClient? marksClient;

  @override
  State<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends State<RideSummaryScreen> {
  late final RideClient _client;
  late final MarksClient _marksClient;
  AppSettings? _settings;
  RideSummary? _summary;
  HealthWindowsResult? _healthWindows;
  bool _healthWindowsLoading = false;
  List<RideMark> _marks = const [];
  bool _marksLoading = false;
  bool _marksSupported = true;
  String? _marksError;
  String? _deletingMarkId;
  String? _error;
  bool _notFound = false;
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? RideClient();
    _marksClient = widget.marksClient ?? MarksClient();
    _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _notFound = false;
        _healthWindows = null;
        _healthWindowsLoading = false;
        _marks = const [];
        _marksLoading = false;
        _marksSupported = true;
        _marksError = null;
        _deletingMarkId = null;
      });
    }
    final settings = await widget.settingsStore.load();
    if (!mounted || requestId != _requestId) return;
    setState(() => _settings = settings);
    if (!settings.isServerConfigured) {
      setState(() => _loading = false);
      return;
    }
    final notFoundText = context.l10n.logbookNoSummary;
    final result = await _client.getSummary(
      baseUrl: settings.serverBaseUrl!,
      apiToken: settings.apiToken ?? '',
      sessionId: widget.sessionId,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _summary = result.data;
        _error = null;
        _notFound = false;
      } else if (result.outcome == RideOutcome.notFound) {
        _summary = null;
        _error = result.message ?? notFoundText;
        _notFound = true;
      } else {
        _summary = null;
        _error = result.message ?? result.outcome.name;
        _notFound = false;
      }
    });
    if (result.isSuccess) {
      await Future.wait([
        _loadHealthWindows(settings, requestId),
        _loadMarks(settings, requestId),
      ]);
    }
  }

  Future<void> _loadMarks(AppSettings settings, int requestId) async {
    setState(() => _marksLoading = true);
    final res = await _marksClient.listRideMarks(
      baseUrl: settings.serverBaseUrl!,
      apiToken: settings.apiToken ?? '',
      rideId: widget.sessionId,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _marksLoading = false;
      if (res.isSuccess && res.data != null) {
        _marks = res.data!;
        _marksSupported = true;
        _marksError = null;
      } else if (res.outcome == MarkCallOutcome.notFound) {
        _marks = const [];
        _marksSupported = false;
        _marksError = null;
      } else {
        _marks = const [];
        _marksSupported = true;
        _marksError = context.l10n.logbookMarksLoadFailed;
      }
    });
  }

  Future<void> _deleteMark(RideMark mark) async {
    final settings = _settings;
    if (settings == null || !settings.isServerConfigured) return;
    final requestId = _requestId;
    setState(() => _deletingMarkId = mark.id);
    final res = await _marksClient.deleteMark(
      baseUrl: settings.serverBaseUrl!,
      apiToken: settings.apiToken ?? '',
      markId: mark.id,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _deletingMarkId = null;
      // 404 = already gone on the server (deleted elsewhere): drop the row too.
      if (res.isSuccess || res.outcome == MarkCallOutcome.notFound) {
        _marks = _marks.where((m) => m.id != mark.id).toList(growable: false);
      }
    });
    if (!res.isSuccess && res.outcome != MarkCallOutcome.notFound) {
      final detail = res.message ?? res.outcome.name;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.logbookMarkDeleteFailed(detail))),
        );
    }
  }

  Future<void> _loadHealthWindows(AppSettings settings, int requestId) async {
    setState(() => _healthWindowsLoading = true);
    final result = await _client.getReport(
      baseUrl: settings.serverBaseUrl!,
      apiToken: settings.apiToken ?? '',
      sessionId: widget.sessionId,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _healthWindowsLoading = false;
      _healthWindows = result.isSuccess
          ? parseHealthWindows(result.data)
          : HealthWindowsResult.unavailable(
              result.message ?? result.outcome.name);
    });
  }

  void _openBringup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BringupScreen(
          sessionId: widget.sessionId,
          settingsStore: widget.settingsStore,
          client: widget.client,
        ),
      ),
    );
  }

  void _openAssistant() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AssistantScreen(
            sessionId: widget.sessionId, settingsStore: widget.settingsStore),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.logbookRideSummaryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: context.l10n.logbookAskAssistant,
            onPressed: _openAssistant,
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: context.l10n.logbookBringupTitle,
            onPressed: _openBringup,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.logbookRefresh,
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final settings = _settings;
    if (settings == null || (_loading && _summary == null && _error == null)) {
      return RideLoading(context.l10n.logbookLoadingSummary);
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
              icon: _notFound ? Icons.search_off : Icons.cloud_off,
              tone: _notFound ? Tone.neutral : Tone.error,
              message: _error!,
              actionLabel: context.l10n.logbookRetry,
              onAction: _load,
            ),
          ),
        ],
      );
    }
    if (_summary == null) {
      return RideLoading(context.l10n.logbookLoadingSummary);
    }
    return _content(settings, _summary!);
  }

  Widget _content(AppSettings settings, RideSummary summary) {
    final computed = summary.signals
        .where((signal) => signal.status == 'computed')
        .toList(growable: false);
    final scalars = computed.whereType<ScalarSummary>().toList(growable: false);
    final perGear =
        computed.whereType<PerGearSummary>().toList(growable: false);
    final binned = computed.whereType<BinnedSummary>().toList(growable: false);
    final unavailable = summary.signals
        .whereType<UnavailableSummary>()
        .where((signal) => signal.status != 'computed')
        .toList(growable: false);
    final mismatch = binned
        .where((signal) => signal.defsMismatch)
        .map((signal) => signal.name)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
      children: [
        if (settings.sendsTokenInCleartext)
          RideCleartextWarning(settings: settings),
        if (mismatch.isNotEmpty)
          InfoBanner(
            icon: Icons.warning_amber_rounded,
            tone: Tone.warn,
            text: context.l10n.logbookDefsMismatch(mismatch.join(', ')),
          ),
        _header(summary),
        if (summary.signals.isEmpty)
          SectionCard(child: Text(context.l10n.logbookNoSignals))
        else ...[
          if (scalars.isNotEmpty) ...[
            SectionLabel(context.l10n.logbookSignals),
            _scalarList(scalars),
          ],
          if (perGear.isNotEmpty) ...[
            SectionLabel(context.l10n.logbookPerGear),
            for (final signal in perGear) _perGearSection(signal),
          ],
          if (binned.isNotEmpty) ...[
            SectionLabel(context.l10n.logbookBinned),
            for (final signal in binned) _binnedSection(signal),
          ],
          if (unavailable.isNotEmpty) ...[
            SectionLabel(context.l10n.logbookCoverage),
            _unavailableList(unavailable),
          ],
        ],
        const SizedBox(height: Spacing.lg),
        SectionLabel(context.l10n.logbookHealthWindows),
        HealthWindowsSection(
          result: _healthWindows,
          loading: _healthWindowsLoading,
          summary: summary,
        ),
        if (_marksSupported) ...[
          const SizedBox(height: Spacing.lg),
          SectionLabel(context.l10n.logbookMarksSection),
          RideMarksSection(
            marks: _marks,
            loading: _marksLoading,
            error: _marksError,
            deletingId: _deletingMarkId,
            onDelete: _deleteMark,
          ),
        ],
      ],
    );
  }

  Widget _header(RideSummary summary) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary.sessionId,
              style: numberFace(24, FontWeight.w600,
                  color: context.vehicle.textPrimary)),
          const SizedBox(height: Spacing.xs),
          Wrap(
            spacing: Spacing.lg,
            runSpacing: Spacing.xs,
            children: [
              Text(l.logbookRideDefinition(summary.rideDefinition ?? '–'),
                  style: theme.textTheme.bodySmall),
              Text(l.logbookDefsVersion(summary.defsVersion ?? '–'),
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scalarList(List<ScalarSummary> scalars) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Wrap(
        spacing: Spacing.xl,
        runSpacing: Spacing.lg,
        children: [
          for (final scalar in scalars)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Readout(
                  label: quantityText(context.l10n, scalar.name),
                  value:
                      RiderFormat.of(context).value(scalar.value, scalar.unit),
                  unit: RiderFormat.of(context).unit(scalar.unit),
                  size: ReadoutSize.medium,
                ),
                if (scalar.flag != null)
                  Text(
                    scalar.flag!,
                    style: theme.textTheme.bodySmall!
                        .copyWith(color: context.vehicle.advisory),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _perGearSection(PerGearSummary signal) {
    final theme = Theme.of(context);
    final gears = [...signal.gears]..sort((a, b) => a.gear.compareTo(b.gear));
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Spacing.md,
              runSpacing: Spacing.xs,
              children: [
                Text(signal.name, style: theme.textTheme.titleSmall),
                Text(signal.unit, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            if (gears.isEmpty)
              Text(context.l10n.logbookNoGears,
                  style: theme.textTheme.bodySmall)
            else
              for (var index = 0; index < gears.length; index++) ...[
                if (index > 0)
                  Divider(height: Spacing.lg, color: context.vehicle.hairline),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(context.l10n.logbookGear(gears[index].gear),
                          style: theme.textTheme.bodyMedium),
                    ),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Spacing.sm,
                        runSpacing: Spacing.xs,
                        children: [
                          Text(
                            RiderFormat.of(context)
                                .withUnit(gears[index].value, signal.unit),
                            style: numberFace(18, FontWeight.w600,
                                color: context.vehicle.textPrimary),
                          ),
                          if (gears[index].flag != null)
                            Text(
                              gears[index].flag!,
                              style: theme.textTheme.bodySmall!
                                  .copyWith(color: context.vehicle.advisory),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _binnedSection(BinnedSummary signal) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Spacing.md,
              runSpacing: Spacing.xs,
              children: [
                Text(signal.name, style: theme.textTheme.titleSmall),
                Text(signal.unit, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            if (signal.axes.length == 1)
              _oneAxisChart(signal)
            else if (signal.axes.length == 2)
              _HeatGrid(signal: signal)
            else
              Text(context.l10n.logbookAxisUnsupported(signal.axes.length),
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: Spacing.sm),
            Text(
              context.l10n.logbookTotalOutside(
                  RiderFormat.of(context).duration(signal.totalS),
                  RiderFormat.of(context).duration(signal.outsideS)),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _oneAxisChart(BinnedSummary signal) {
    final theme = Theme.of(context);
    final axis = signal.axes.first;
    final edgeRange = rideAxisRange(axis.edges);
    final values = axis.edges
        .asMap()
        .entries
        .map((entry) => _cellAt(signal, [entry.key])?.value)
        .toList(growable: false);
    final heights = barHeights(values, 64);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${axis.input} [${axis.unit}]', style: theme.textTheme.bodySmall),
        const SizedBox(height: Spacing.xs),
        SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < axis.edges.length; index++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message:
                          '${_edgeText(axis.edges[index], edgeRange)} ${axis.unit}: '
                          '${RiderFormat.of(context).value(values[index], signal.unit)}',
                      child: Container(
                        height: heights[index],
                        decoration: BoxDecoration(
                          color: context.vehicle.accent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Row(
          children: [
            for (final edge in axis.edges)
              Expanded(
                child: Text(
                  _edgeText(edge, edgeRange),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _unavailableList(List<UnavailableSummary> unavailable) {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(context.l10n.logbookNotAvailable(unavailable.length)),
        childrenPadding:
            const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
        children: [
          for (final signal in unavailable)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: _unavailableRow(signal),
            ),
        ],
      ),
    );
  }

  Widget _unavailableRow(UnavailableSummary signal) {
    final theme = Theme.of(context);
    final details = <String>[
      if (signal.reason != null && signal.reason!.isNotEmpty) signal.reason!,
      if (signal.pendingInputs.isNotEmpty)
        context.l10n.logbookPendingInputs(signal.pendingInputs.join(', ')),
      if (signal.missing.isNotEmpty)
        context.l10n.logbookMissingInputs(signal.missing.join(', ')),
      if (signal.message != null && signal.message!.isNotEmpty) signal.message!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.xs,
          children: [
            Text(signal.name, style: theme.textTheme.bodyMedium),
            Text(signal.status, style: theme.textTheme.bodySmall),
          ],
        ),
        if (details.isNotEmpty)
          Text(details.join(' · '), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

RideCell? _cellAt(BinnedSummary signal, List<int> indices) {
  for (final cell in signal.cells) {
    if (cell.axes.length == indices.length) {
      var matches = true;
      for (var index = 0; index < indices.length; index++) {
        if (cell.axes[index] != indices[index]) {
          matches = false;
          break;
        }
      }
      if (matches) return cell;
    }
  }
  return null;
}

String _edgeText(RideRange edge, RideRange range) =>
    '${formatRideRangeValue(edge.min, range)}–${formatRideRangeValue(edge.max, range)}';

class _HeatGrid extends StatefulWidget {
  const _HeatGrid({required this.signal});

  final BinnedSummary signal;

  @override
  State<_HeatGrid> createState() => _HeatGridState();
}

class _HeatGridState extends State<_HeatGrid> {
  static const double _labelWidth = 72;
  static const double _cellSize = 26;

  int? _selectedRow;
  int? _selectedColumn;

  @override
  Widget build(BuildContext context) {
    final signal = widget.signal;
    // Rows = axes[0], columns = axes[1]: the server's row-major cell order
    // and the analyzer's grid (RideSummary.tsx).
    final rows = signal.axes[0];
    final columns = signal.axes[1];
    final rowRange = rideAxisRange(rows.edges);
    final columnRange = rideAxisRange(columns.edges);
    final max = maxCellValue(signal.cells);
    final theme = Theme.of(context);
    final selected = _selectedRow != null && _selectedColumn != null
        ? _cellAt(signal, [_selectedRow!, _selectedColumn!])
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.logbookColumnsAxis(columns.input, columns.unit),
            style: theme.textTheme.bodySmall),
        const SizedBox(height: Spacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = math.max(constraints.maxWidth,
                _labelWidth + columns.edges.length * _cellSize);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: _labelWidth),
                        for (final edge in columns.edges)
                          SizedBox(
                            width: _cellSize,
                            child: Text(
                              _edgeText(edge, columnRange),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                    for (var row = 0; row < rows.edges.length; row++)
                      Row(
                        children: [
                          SizedBox(
                            width: _labelWidth,
                            child: Text(
                              _edgeText(rows.edges[row], rowRange),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          for (var column = 0;
                              column < columns.edges.length;
                              column++)
                            _heatCell(signal, columns, rows, row, column, max),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: Spacing.xs),
        Text(context.l10n.logbookRowsAxis(rows.input, rows.unit),
            style: theme.textTheme.bodySmall),
        if (selected != null || _selectedRow != null)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: Text(
              _selectedText(signal, columns, rows, selected),
              key: ValueKey('heat-selected-${signal.name}'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }

  Widget _heatCell(
    BinnedSummary signal,
    RideAxis columns,
    RideAxis rows,
    int row,
    int column,
    double max,
  ) {
    final cell = _cellAt(signal, [row, column]);
    final opacity = heatOpacity(cell?.value, max);
    final isSelected = _selectedRow == row && _selectedColumn == column;
    final rowRange = rideAxisRange(rows.edges);
    final columnRange = rideAxisRange(columns.edges);
    return Tooltip(
      message: '${_edgeText(rows.edges[row], rowRange)} / '
          '${_edgeText(columns.edges[column], columnRange)}: '
          '${RiderFormat.of(context).withUnit(cell?.value, signal.unit)}'
          '${cell?.flag != null ? ' · ${cell!.flag}' : ''}',
      child: InkWell(
        key: ValueKey('heat-cell-${signal.name}-$row-$column'),
        onTap: () => setState(() {
          _selectedRow = row;
          _selectedColumn = column;
        }),
        child: Container(
          width: _cellSize,
          height: _cellSize,
          decoration: BoxDecoration(
            color: opacity > 0
                ? context.vehicle.accent.withValues(alpha: opacity)
                : context.vehicle.surfaceRaised,
            border: Border.all(
              color: isSelected
                  ? context.vehicle.textPrimary
                  : context.vehicle.hairline,
              width: isSelected ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }

  String _selectedText(
      BinnedSummary signal, RideAxis columns, RideAxis rows, RideCell? cell) {
    final row = _selectedRow!;
    final column = _selectedColumn!;
    final value = RiderFormat.of(context).withUnit(cell?.value, signal.unit);
    final flag = cell?.flag;
    final rowRange = rideAxisRange(rows.edges);
    final columnRange = rideAxisRange(columns.edges);
    return '${_edgeText(rows.edges[row], rowRange)} / '
        '${_edgeText(columns.edges[column], columnRange)}: '
        '$value${flag != null ? ' · $flag' : ''}';
  }
}
