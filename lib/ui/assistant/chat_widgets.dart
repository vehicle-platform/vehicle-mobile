import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/chat_message.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/readout.dart';

/// Localized label of where an answer text came from: text the model
/// phrased, or a fixed template over the tool result (every number checked
/// against the data).
String chatSourceLabel(AppLocalizations l, ChatSource source) =>
    switch (source) {
      ChatSource.llm => l.assistantSourceLlm,
      ChatSource.template => l.assistantSourceTemplate,
      ChatSource.unsupported => l.assistantSourceUnsupported,
      ChatSource.error => l.assistantSourceError,
    };

/// `HH:mm` of a transcript line.
String chatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// One transcript entry (D-130 item 3): the rider's question as a plain
/// timestamped line, the assistant's answer as plain text followed by data
/// cards. No bubbles, no avatars. New entries fade in (<= 200 ms).
class TranscriptEntry extends StatelessWidget {
  const TranscriptEntry({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final child = message.role == ChatRole.user
        ? _QuestionLine(message: message)
        : _Answer(message: message);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.standard,
      curve: Motion.curve,
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: child,
    );
  }
}

class _QuestionLine extends StatelessWidget {
  const _QuestionLine({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: t.hairline))),
      padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(chatClock(message.time),
              key: const ValueKey('line-time'),
              style: numberFace(14, FontWeight.w500, color: t.textSecondary)),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: SelectableText(message.text,
                style: theme.textTheme.bodyLarge!
                    .copyWith(color: t.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final t = context.vehicle;
    final failure = message.isFailure;
    final note = switch (message.modelNote) {
      ChatModelNote.template => l.assistantModelTemplate,
      ChatModelNote.unsupported => l.assistantModelNone,
      null => message.modelCaption,
    };
    final text = SelectableText(message.text,
        style: theme.textTheme.bodyLarge!.copyWith(height: 1.45));
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.source != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: Row(
                children: [
                  SourceBadge(message.source!),
                  const Spacer(),
                  if (message.elapsedMs != null)
                    Text('${message.elapsedMs} ms',
                        style: numberFace(13, FontWeight.w500,
                            color: t.textSecondary)),
                ],
              ),
            ),
          if (failure)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: Spacing.md),
              decoration: BoxDecoration(
                  border:
                      Border(left: BorderSide(color: t.critical, width: 4))),
              child: text,
            )
          else
            text,
          if (message.tool != null)
            DataCard(tool: message.tool!, result: message.result),
          if (note != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              note,
              key: const ValueKey('model-caption'),
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Where an answer came from: a small letter-spaced caption, coloured by
/// state (verified = teal, could not answer = amber, error = red).
class SourceBadge extends StatelessWidget {
  const SourceBadge(this.source, {super.key});

  final ChatSource source;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final color = switch (source) {
      ChatSource.llm => t.textSecondary,
      ChatSource.template => t.live,
      ChatSource.unsupported => t.advisory,
      ChatSource.error => t.critical,
    };
    return Text(
      upperFor(context, chatSourceLabel(context.l10n, source)),
      style: Theme.of(context).textTheme.labelSmall!.copyWith(color: color),
    );
  }
}

/// Data card of an answer (D-130 item 3, invariant 7): the labelled values of
/// the tool result with their units, exactly as the vehicle-mcp tool computed
/// them, and a "computed by <tool>" line that expands to the verbatim
/// arguments and result rows.
class DataCard extends StatelessWidget {
  const DataCard({super.key, required this.tool, this.result});

  final ChatToolCall tool;
  final Object? result;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final t = context.vehicle;
    final labels = ChatFlattenLabels(
      items: l.assistantItemCount,
      more: l.assistantMoreItems,
      truncated: l.assistantTruncated,
    );
    final args = flattenChatValue(tool.arguments, labels: labels);
    final resultRows = flattenChatValue(result, key: 'result', labels: labels);
    final data = chatData(resultRows);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: Spacing.md),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: t.hairline),
          bottom: BorderSide(color: t.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.md),
              child: Wrap(
                spacing: Spacing.xl,
                runSpacing: Spacing.lg,
                children: [
                  for (final d in data)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Readout(
                        label: d.label,
                        value: d.value,
                        unit: d.unit,
                        size: ReadoutSize.small,
                      ),
                    ),
                ],
              ),
            ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: Spacing.sm),
              dense: true,
              minTileHeight: Spacing.touchTarget,
              title: Text.rich(
                TextSpan(
                  style: theme.textTheme.bodySmall,
                  children: [
                    TextSpan(text: l.assistantComputedBy),
                    TextSpan(
                      text: tool.name,
                      style:
                          numberFace(14, FontWeight.w600, color: t.textPrimary),
                    ),
                  ],
                ),
              ),
              children: [
                if (args.isNotEmpty) ...[
                  _RowsHeader(l.assistantArguments),
                  for (final row in args)
                    _ToolRow(label: row.key, value: row.value),
                ],
                _RowsHeader(l.assistantResult),
                if (resultRows.isEmpty)
                  _ToolRow(label: 'result', value: l.assistantResultEmpty)
                else
                  for (final row in resultRows)
                    _ToolRow(label: row.key, value: row.value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowsHeader extends StatelessWidget {
  const _RowsHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Spacing.xs, bottom: 2),
        child: Text(upperFor(context, text),
            style: Theme.of(context).textTheme.labelSmall),
      );
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 5, child: Text(label, style: theme.textTheme.bodySmall)),
          const SizedBox(width: Spacing.md),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: numberFace(15, FontWeight.w600,
                  color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Follow-up chips under the latest answer (`chips` of the response; absent
/// means none). Tapping one asks it as the next question.
class FollowUpChips extends StatelessWidget {
  const FollowUpChips({super.key, required this.chips, required this.onTap});

  final List<String> chips;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        children: [
          for (final chip in chips)
            ActionChip(
              label: Text(chip),
              onPressed: () => onTap(chip),
            ),
        ],
      ),
    );
  }
}

/// Honest step line while the host works: plain text, no animation dots.
class AssistantStepLine extends StatelessWidget {
  const AssistantStepLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          children: [
            Text(chatClock(DateTime.now()),
                style: numberFace(14, FontWeight.w500, color: t.textSecondary)),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: t.accent)),
            ),
          ],
        ),
      ),
    );
  }
}
