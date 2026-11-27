import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/ride_mark.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// Result returned by [showRideMarkPicker]: chosen [kind] plus an optional
/// [note] (empty or whitespace-only notes normalize to `null`).
class RideMarkSelection {
  const RideMarkSelection({required this.kind, this.note});

  final RideMarkKind kind;
  final String? note;
}

/// Glove-friendly quick picker for the 4 most common ride event kinds + other,
/// with a "More" entry for all seven D-133 kinds and an optional note
/// (<= 200 characters) when picking "Other" or opening "More".
///
/// Closes itself automatically after [autoCloseAfter] so a rider does not have
/// to hunt for a dismiss button while riding; the timer pauses while the note
/// field has focus.
Future<RideMarkSelection?> showRideMarkPicker(
  BuildContext context, {
  Duration autoCloseAfter = const Duration(seconds: 5),
}) {
  return showModalBottomSheet<RideMarkSelection>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RideMarkPickerSheet(autoCloseAfter: autoCloseAfter),
  );
}

enum _PickerView { quick, more, otherNote }

class _RideMarkPickerSheet extends StatefulWidget {
  const _RideMarkPickerSheet({required this.autoCloseAfter});

  final Duration autoCloseAfter;

  @override
  State<_RideMarkPickerSheet> createState() => _RideMarkPickerSheetState();
}

class _RideMarkPickerSheetState extends State<_RideMarkPickerSheet> {
  Timer? _autoCloseTimer;
  _PickerView _view = _PickerView.quick;
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _noteFocus.addListener(_onNoteFocusChanged);
    _startAutoCloseTimer();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _noteFocus
      ..removeListener(_onNoteFocusChanged)
      ..dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _startAutoCloseTimer() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(widget.autoCloseAfter, () {
      if (mounted && !_noteFocus.hasFocus) {
        Navigator.of(context).pop();
      }
    });
  }

  void _onNoteFocusChanged() {
    if (_noteFocus.hasFocus) {
      _autoCloseTimer?.cancel();
      _autoCloseTimer = null;
    } else if (mounted) {
      _startAutoCloseTimer();
    }
  }

  String? _normalizedNote() {
    final trimmed = _noteController.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _submit(RideMarkKind kind, {bool includeNote = false}) {
    Navigator.of(context).pop(
      RideMarkSelection(
        kind: kind,
        note: includeNote ? _normalizedNote() : null,
      ),
    );
  }

  void _switchView(_PickerView next) {
    setState(() => _view = next);
    if (!_noteFocus.hasFocus) {
      _startAutoCloseTimer();
    }
  }

  IconData _iconOf(RideMarkKind kind) => switch (kind) {
        RideMarkKind.vibration => Icons.vibration,
        RideMarkKind.noise => Icons.hearing,
        RideMarkKind.misfire => Icons.bolt,
        RideMarkKind.warningLight => Icons.warning_amber_rounded,
        RideMarkKind.roughRoad => Icons.terrain,
        RideMarkKind.traffic => Icons.traffic,
        RideMarkKind.other => Icons.flag_outlined,
      };

  Widget _noteField(BuildContext context, {VoidCallback? onSubmitted}) {
    final l = context.l10n;
    return TextField(
      key: const ValueKey('mark-note-field'),
      controller: _noteController,
      focusNode: _noteFocus,
      maxLength: maxRideMarkNoteLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      maxLines: 2,
      minLines: 1,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
      decoration: InputDecoration(
        labelText: l.rideMarkNoteLabel,
        hintText: l.rideMarkNoteHint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _kindButton(
    BuildContext context,
    RideMarkKind kind, {
    required VoidCallback onPressed,
  }) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return FilledButton.tonalIcon(
      key: ValueKey('mark-kind-${kind.wireName}'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      ),
      onPressed: onPressed,
      icon: Icon(_iconOf(kind), size: 24),
      label: Text(
        kind.label(l),
        style: theme.textTheme.titleMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.lg,
          Spacing.lg,
          Spacing.xl + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.rideMarkPickerTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.xs),
            Text(l.rideMarkPickerHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: Spacing.md),
            if (_view == _PickerView.quick) ...[
              for (final kind in RideMarkKind.quickPickerKinds) ...[
                _kindButton(
                  context,
                  kind,
                  onPressed: () {
                    if (kind == RideMarkKind.other) {
                      _switchView(_PickerView.otherNote);
                    } else {
                      _submit(kind);
                    }
                  },
                ),
                const SizedBox(height: Spacing.sm),
              ],
              OutlinedButton.icon(
                key: const ValueKey('mark-kind-more'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                ),
                onPressed: () => _switchView(_PickerView.more),
                icon: const Icon(Icons.more_horiz, size: 24),
                label: Text(
                  l.rideMarkPickerMore,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ] else if (_view == _PickerView.otherNote) ...[
              _noteField(
                context,
                onSubmitted: () => _submit(RideMarkKind.other, includeNote: true),
              ),
              const SizedBox(height: Spacing.md),
              FilledButton.icon(
                key: const ValueKey('mark-note-submit'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => _submit(RideMarkKind.other, includeNote: true),
                icon: Icon(_iconOf(RideMarkKind.other), size: 24),
                label: Text(
                  '${l.rideMarkSave} (${RideMarkKind.other.label(l)})',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ] else ...[
              _noteField(context),
              const SizedBox(height: Spacing.md),
              for (final kind in RideMarkKind.allPickerKinds) ...[
                _kindButton(
                  context,
                  kind,
                  onPressed: () => _submit(kind, includeNote: true),
                ),
                const SizedBox(height: Spacing.sm),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
