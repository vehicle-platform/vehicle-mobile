import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/ride_summary.dart';
import '../../services/app_settings.dart';
import '../../services/ride_client.dart';
import '../telemetry/link_status.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'ride_format.dart';
import 'ride_widgets.dart';

class RideSummaryScreen extends StatefulWidget {
  const RideSummaryScreen({
    super.key,
    required this.sessionId,
    this.settingsStore = const AppSettingsStore(),
    this.client,
  });

  final String sessionId;
  final AppSettingsStore settingsStore;
  final RideClient? client;

  @override
  State<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends State<RideSummaryScreen> {
  late final RideClient _client;
  AppSettings? _settings;
  RideSummary? _summary;
  String? _error;
  bool _notFound = false;
  bool _loading = true;
  int _requestId = 0;

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
        _notFound = false;
      });
    }
    final settings = await widget.settingsStore.load();
    if (!mounted || requestId != _requestId) return;
    setState(() => _settings = settings);
    if (!settings.isServerConfigured) {
      setState(() => _loading = false);
      return;
    }
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
        _error = result.message ?? 'No stored ride summary for this session.';
        _notFound = true;
      } else {
        _summary = null;
        _error = result.message ?? result.outcome.name;
        _notFound = false;
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride summary'),
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
    if (settings == null || (_loading && _summary == null && _error == null)) {
      return const RideLoading('Loading ride summary...');
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
              icon: _notFound ? Icons.search_off : Icons.cloud_off,
              tone: _notFound ? Tone.neutral : Tone.error,
              message: _error!,
              actionLabel: 'Retry',
              onAction: _load,
            ),
          ),
        ],
      );
    }
    if (_summary == null) return const RideLoading('Loading ride summary...');
    return _content(settings, _summary!);
  }

  Widget _content(AppSettings settings, RideSummary summary) {
    final computed = summary.signals
        .where((signal) => signal.status == 'computed')
        .toList(growable: false);
    final scalars = computed.whereType<ScalarSummary>().toList(growable: false);
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
            text: 'Decoded with other defs bin edges: ${mismatch.join(', ')}.',
          ),
        _header(summary),
        if (summary.signals.isEmpty)
          const SectionCard(
              child: Text('No stored signals in this ride summary.'))
        else ...[
          if (scalars.isNotEmpty) ...[
            const SectionLabel('Signals'),
            _scalarList(scalars),
          ],
          if (binned.isNotEmpty) ...[
            const SectionLabel('Binned signals'),
            for (final signal in binned) _binnedSection(signal),
          ],
          if (unavailable.isNotEmpty) ...[
            const SectionLabel('Coverage'),
            _unavailableList(unavailable),
          ],
        ],
      ],
    );
  }

  Widget _header(RideSummary summary) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary.sessionId, style: theme.textTheme.titleSmall),
          const SizedBox(height: Spacing.xs),
          Wrap(
            spacing: Spacing.lg,
            runSpacing: Spacing.xs,
            children: [
              Text('ride ${summary.rideDefinition ?? '–'}',
                  style: theme.textTheme.bodySmall),
              Text('defs ${summary.defsVersion ?? '–'}',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scalarList(List<ScalarSummary> scalars) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < scalars.length; index++) ...[
            if (index > 0)
              Divider(height: Spacing.lg, color: context.vehicle.outline),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Spacing.md,
                    runSpacing: Spacing.xs,
                    children: [
                      Text(scalars[index].name,
                          style: theme.textTheme.bodyMedium),
                      Text(
                        '${formatRideRangeValue(scalars[index].value, scalars[index].range)} ${scalars[index].unit}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  if (scalars[index].flag != null)
                    Text(
                      scalars[index].flag!,
                      style: theme.textTheme.bodySmall!
                          .copyWith(color: context.vehicle.warning),
                    ),
                ],
              ),
            ),
          ],
        ],
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
              Text('${signal.axes.length}-axis summaries are not shown on the phone yet.',
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: Spacing.sm),
            Text(
              'total ${formatDurationS(signal.totalS)} · outside ${formatDurationS(signal.outsideS)}',
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
                          '${formatRideRangeValue(values[index], signal.range)}',
                      child: Container(
                        height: heights[index],
                        decoration: BoxDecoration(
                          color: context.vehicle.accent,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2)),
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
        title: Text('Not available (${unavailable.length})'),
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
        'pending: ${signal.pendingInputs.join(', ')}',
      if (signal.missing.isNotEmpty) 'missing: ${signal.missing.join(', ')}',
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
        Text('columns: ${columns.input} [${columns.unit}]',
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
        Text('rows: ${rows.input} [${rows.unit}]',
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
      message:
          '${_edgeText(rows.edges[row], rowRange)} / '
          '${_edgeText(columns.edges[column], columnRange)}: '
          '${formatRideRangeValue(cell?.value, signal.range)} ${signal.unit}'
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
                  : context.vehicle.outline,
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
    final value =
        '${formatRideRangeValue(cell?.value, signal.range)} ${signal.unit}';
    final flag = cell?.flag;
    final rowRange = rideAxisRange(rows.edges);
    final columnRange = rideAxisRange(columns.edges);
    return '${_edgeText(rows.edges[row], rowRange)} / '
        '${_edgeText(columns.edges[column], columnRange)}: '
        '$value${flag != null ? ' · $flag' : ''}';
  }
}
