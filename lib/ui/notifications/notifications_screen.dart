import 'package:flutter/material.dart';

import 'package:vehicle_mobile/models/app_notification.dart';
import 'package:vehicle_mobile/ui/notifications/notification_scope.dart';
import 'package:vehicle_mobile/ui/rides/ride_summary_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';

IconData notificationKindIcon(NotificationKind kind) => switch (kind) {
      NotificationKind.rideSummary => Icons.route_outlined,
      NotificationKind.fault => Icons.report_problem_outlined,
      NotificationKind.dataQuality => Icons.fact_check_outlined,
      NotificationKind.outlook => Icons.trending_up,
    };

/// Severity accent: critical red, warning amber, info teal.
Color notificationSeverityColor(BuildContext context, NotificationSeverity s) {
  final t = context.vehicle;
  return switch (s) {
    NotificationSeverity.critical => t.error,
    NotificationSeverity.warning => t.stale,
    NotificationSeverity.info => t.accent,
  };
}

String notificationSeverityLabel(NotificationSeverity s) => switch (s) {
      NotificationSeverity.critical => 'Kritik',
      NotificationSeverity.warning => 'Uyarı',
      NotificationSeverity.info => 'Bilgi',
    };

String _two(int v) => v.toString().padLeft(2, '0');

String notificationTime(DateTime? time) =>
    time == null ? '' : '${_two(time.hour)}:${_two(time.minute)}';

/// "Bugün", "Dün" or dd.MM.yyyy.
String notificationDayLabel(DateTime? day, {DateTime? now}) {
  if (day == null) return 'Tarih yok';
  final today = now ?? DateTime.now();
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return 'Bugün';
  if (diff == 1) return 'Dün';
  return '${_two(day.day)}.${_two(day.month)}.${day.year}';
}

/// Inbox of the rider notifications (D-123), newest first, grouped by day.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, this.now});

  /// Clock for the day headers (tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final scope = NotificationScope.maybeOf(context);
    final center = scope?.notifier;
    final items = center?.items ?? const <AppNotification>[];
    final theme = Theme.of(context);

    final rows = <Widget>[];
    String? lastDay;
    for (final n in items) {
      final day = notificationDayLabel(n.created, now: now);
      if (day != lastDay) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: Spacing.lg, bottom: Spacing.sm),
          child: Text(day.toUpperCase(), style: theme.textTheme.labelSmall),
        ));
        lastDay = day;
      }
      rows.add(_NotificationRow(
        notification: n,
        onTap: () {
          center!.markRead(n.id);
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => NotificationScope(
              center: center,
              onAsk: scope!.onAsk,
              child: NotificationDetailScreen(notification: n),
            ),
          ));
        },
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            tooltip: 'Tümünü okundu say',
            icon: const Icon(Icons.done_all),
            onPressed: (center == null || center.unreadCount == 0)
                ? null
                : center.markAllRead,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => center?.refresh(full: true) ?? Future.value(),
        child: items.isEmpty
            ? LayoutBuilder(
                builder: (_, c) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: c.maxHeight,
                    child: const EmptyState(
                      icon: Icons.notifications_none,
                      message: 'Henüz bildirim yok',
                      hint: 'Sürüş özetleri ve uyarılar burada görünür.',
                    ),
                  ),
                ),
              )
            : ContentColumn(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.lg, 0, Spacing.lg, Spacing.xl),
                  children: rows,
                ),
              ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    final accent = notificationSeverityColor(context, notification.severity);
    final n = notification;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: t.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(notificationKindIcon(n.kind),
                            size: IconSizes.regular, color: accent),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall!.copyWith(
                                    fontWeight: n.read
                                        ? FontWeight.w500
                                        : FontWeight.w700),
                              ),
                              if (n.body.isNotEmpty) ...[
                                const SizedBox(height: Spacing.xs),
                                Text(n.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(notificationTime(n.created),
                                style: theme.textTheme.bodySmall),
                            if (!n.read) ...[
                              const SizedBox(height: Spacing.sm),
                              Container(
                                key: const ValueKey('unread-dot'),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: accent, shape: BoxShape.circle),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Maximum characters of the prefilled assistant question (the server accepts
/// 500).
const int _maxQuestion = 500;

/// Question the "Sürüş Asistanı'na sor" button prefills.
String notificationQuestion(AppNotification n) {
  final text = '"${n.title}" bildirimi hakkında ne söyleyebilirsin?';
  return text.length <= _maxQuestion
      ? text
      : '${text.substring(0, _maxQuestion - 1)}…';
}

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = notificationSeverityColor(context, notification.severity);
    final n = notification;
    final onAsk = NotificationScope.maybeOf(context)?.onAsk;
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim')),
      body: ContentColumn(
        maxWidth: ContentWidth.assistant,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
          children: [
            Row(
              children: [
                Icon(notificationKindIcon(n.kind),
                    size: IconSizes.regular, color: accent),
                const SizedBox(width: Spacing.sm),
                Text(notificationSeverityLabel(n.severity),
                    style:
                        theme.textTheme.labelMedium!.copyWith(color: accent)),
                const Spacer(),
                Text(
                    '${notificationDayLabel(n.created)} ${notificationTime(n.created)}'
                        .trim(),
                    style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text(n.title, style: theme.textTheme.titleLarge),
            if (n.body.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              Text(n.body, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: Spacing.xl),
            if (n.sessionId != null) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.route_outlined),
                label: const Text('Sürüşü aç'),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            RideSummaryScreen(sessionId: n.sessionId!))),
              ),
              const SizedBox(height: Spacing.sm),
            ],
            if (onAsk != null)
              FilledButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text("Sürüş Asistanı'na sor"),
                onPressed: () => onAsk(notificationQuestion(n), n.sessionId),
              ),
          ],
        ),
      ),
    );
  }
}
