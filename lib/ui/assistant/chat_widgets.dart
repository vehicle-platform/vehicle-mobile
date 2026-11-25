import 'package:flutter/material.dart';

import 'package:vehicle_mobile/models/chat_message.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// Short Turkish label of where an answer text came from: `Asistan` for text the
/// local model phrased, `Veriden doğrulandı` for a fixed template over the
/// tool result (every number checked against the data).
String chatSourceLabel(ChatSource source) => switch (source) {
      ChatSource.llm => 'Asistan',
      ChatSource.template => 'Veriden doğrulandı',
      ChatSource.unsupported => 'Yanıtlanamadı',
      ChatSource.error => 'Hata',
    };

/// Assistant avatar: a motorcycle glyph on a soft accent disc (no brand marks).
class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: t.accent.withValues(alpha: 0.16)),
      child: Icon(Icons.two_wheeler, size: size * 0.55, color: t.accent),
    );
  }
}

/// One conversation entry: the rider's question as a compact right-aligned
/// pill, the assistant's answer as a full-width flat card. New entries fade and slide
/// in (<= 200 ms).
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final child = message.role == ChatRole.user ? _QuestionPill(text: message.text) : _AnswerCard(message: message);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child),
      ),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 2), child: child),
    );
  }
}

class _QuestionPill extends StatelessWidget {
  const _QuestionPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md - 2),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(22),
          ),
          child: SelectableText(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    final failure = message.isFailure;
    // A Material (not a decorated box) so the tool card's ListTile can paint.
    return Material(
      color: failure ? t.error.withValues(alpha: 0.10) : t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: failure ? t.error.withValues(alpha: 0.5) : t.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (failure) Icon(Icons.info_outline, size: 20, color: t.error) else const AssistantAvatar(size: 24),
                const SizedBox(width: Spacing.sm),
                if (message.source != null) SourceBadge(message.source!),
                const Spacer(),
                if (message.elapsedMs != null) Text('${message.elapsedMs} ms', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: Spacing.md),
            SelectableText(message.text, style: theme.textTheme.bodyLarge!.copyWith(fontSize: 17, height: 1.45)),
            if (message.tool != null) ToolCard(tool: message.tool!, result: message.result),
          ],
        ),
      ),
    );
  }
}

/// Subtle chip saying where an answer came from.
class SourceBadge extends StatelessWidget {
  const SourceBadge(this.source, {super.key});

  final ChatSource source;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final color = switch (source) {
      ChatSource.llm => t.textSecondary,
      ChatSource.template => t.live,
      ChatSource.unsupported => t.stale,
      ChatSource.error => t.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 2, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        chatSourceLabel(source),
        style: Theme.of(context).textTheme.labelMedium!.copyWith(color: color, letterSpacing: 0.2),
      ),
    );
  }
}

/// Quiet, collapsible "computed by <tool>" row (invariant 7): every number the
/// rider sees is traceable to the vehicle-mcp tool that computed it. The
/// arguments and the result are shown verbatim as flattened key/value rows in
/// tabular figures.
class ToolCard extends StatelessWidget {
  const ToolCard({super.key, required this.tool, this.result});

  final ChatToolCall tool;
  final Object? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    final args = flattenChatValue(tool.arguments);
    final resultRows = flattenChatValue(result, key: 'result');
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: Spacing.sm),
          dense: true,
          minTileHeight: Spacing.touchTarget,
          leading: Icon(Icons.functions, size: 18, color: t.textSecondary),
          title: Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall,
              children: [
                const TextSpan(text: 'computed by '),
                TextSpan(
                  text: tool.name,
                  style: theme.textTheme.bodySmall!.copyWith(
                    fontFamily: 'monospace',
                    color: t.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          children: [
            if (args.isNotEmpty) ...[
              const _RowsHeader('Arguments'),
              for (final row in args) _ToolRow(label: row.key, value: row.value),
            ],
            const _RowsHeader('Result'),
            if (resultRows.isEmpty)
              const _ToolRow(label: 'result', value: '(empty)')
            else
              for (final row in resultRows) _ToolRow(label: row.key, value: row.value),
          ],
        ),
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
        child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
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
          Expanded(flex: 5, child: Text(label, style: theme.textTheme.bodySmall)),
          const SizedBox(width: Spacing.md),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
