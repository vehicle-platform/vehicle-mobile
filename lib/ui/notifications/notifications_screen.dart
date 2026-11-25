import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/app_notification.dart';
import 'package:vehicle_mobile/ui/notifications/notification_scope.dart';
import 'package:vehicle_mobile/ui/rides/ride_summary_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';
import 'package:vehicle_mobile/ui/widgets/alert_banner.dart';

IconData notificationKindIcon(NotificationKind kind) => switch (kind) {
      NotificationKind.rideSummary => Icons.route_outlined,
      NotificationKind.fault => Icons.report_problem_outlined,
      NotificationKind.dataQuality => Icons.fact_check_outlined,
      NotificationKind.outlook => Icons.trending_up,
    };

/// Severity colour (D-130 item 1): critical red, warning amber, info neutral.
Color notificationSeverityColor(BuildContext context, NotificationSeverity s) {
  final t = context.vehicle;
  return switch (s) {
    NotificationSeverity.critical => t.critical,
    NotificationSeverity.warning => t.advisory,
    NotificationSeverity.info => t.noData,
  };
}

/// D-129 class of a severity: critical is P1, warning P2, info has no banner.
AlertClass? notificationAlertClass(NotificationSeverity s) => switch (s) {
      NotificationSeverity.critical => AlertClass.p1,
      NotificationSeverity.warning => AlertClass.p2,
      NotificationSeverity.info => null,
    };

String notificationSeverityLabel(AppLocalizations l, NotificationSeverity s) =>
    switch (s) {
      NotificationSeverity.critical => l.garageSeverityCritical,
      NotificationSeverity.warning => l.garageSeverityWarning,
      NotificationSeverity.info => l.garageSeverityInfo,
    };

String _two(int v) => v.toString().padLeft(2, '0');

String notificationTime(DateTime? time) =>
    time == null ? '' : '${_two(time.hour)}:${_two(time.minute)}';

/// "Today", "Yesterday" or dd.MM.yyyy.
String notificationDayLabel(AppLocalizations l, DateTime? day,
    {DateTime? now}) {
  if (day == null) return l.garageDayNoDate;
  final today = now ?? DateTime.now();
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return l.garageDayToday;
  if (diff == 1) return l.garageDayYesterday;
  return '${_two(day.day)}.${_two(day.month)}.${day.year}';
}

/// The newest unread critical (P1) or warning (P2) notification, which the
/// inbox shows as an [AlertBanner]; null when there is none. Critical wins
/// over a newer warning.
AppNotification? bannerNotification(List<AppNotification> items) {
  AppNotification? warning;
  for (final n in items) {
    if (n.read) continue;
    if (n.severity == NotificationSeverity.critical) return n;
    if (n.severity == NotificationSeverity.warning) warning ??= n;
  }
  return warning;
}

/// Inbox of the rider notifications (D-123), newest first, grouped by day.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen(
      {super.key, this.now, this.embedded = false, this.onOpen});

  /// Inside the Garage destination: no scaffold or app bar of its own.
  final bool embedded;

  /// Wide layout: shows the notification in the detail pane instead of
  /// pushing the detail route.
  final ValueChanged<AppNotification>? onOpen;

  /// Clock for the day headers (tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scope = NotificationScope.maybeOf(context);
    final center = scope?.notifier;
    final items = center?.items ?? const <AppNotification>[];
    final theme = Theme.of(context);

    void open(AppNotification n) {
      center!.markRead(n.id);
      final onOpen = this.onOpen;
      if (onOpen != null) {
        onOpen(n);
        return;
      }
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => NotificationScope(
          center: center,
          onAsk: scope!.onAsk,
          child: NotificationDetailScreen(notification: n),
        ),
      ));
    }

    final rows = <Widget>[];
    String? lastDay;
    for (final n in items) {
      final day = notificationDayLabel(l, n.created, now: now);
      if (day != lastDay) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: Spacing.lg, bottom: Spacing.sm),
          child:
              Text(upperFor(context, day), style: theme.textTheme.labelSmall),
        ));
        lastDay = day;
      }
      rows.add(_NotificationRow(notification: n, onTap: () => open(n)));
    }

    final banner = bannerNotification(items);
    final list = RefreshIndicator(
      onRefresh: () => center?.refresh(full: true) ?? Future.value(),
      child: items.isEmpty
          ? LayoutBuilder(
              builder: (_, c) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: c.maxHeight,
                  child: EmptyState(
                    icon: Icons.notifications_none,
                    message: l.garageEmptyTitle,
                    hint: l.garageEmptyHint,
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
    );
    final body = Column(
      children: [
        if (banner != null)
          AlertBanner(
            key: const ValueKey('inbox-alert-banner'),
            alertClass: notificationAlertClass(banner.severity)!,
            message: banner.title,
            onTap: () => open(banner),
            trailing: const Padding(
              padding: EdgeInsets.only(left: Spacing.sm),
              child: Icon(Icons.chevron_right),
            ),
          ),
        Expanded(child: list),
      ],
    );
    final markAll = IconButton(
      tooltip: l.garageMarkAllRead,
      icon: const Icon(Icons.done_all),
      onPressed: (center == null || center.unreadCount == 0)
          ? null
          : center.markAllRead,
    );
    if (embedded) {
      return Column(
        children: [
          Align(alignment: Alignment.centerRight, child: markAll),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.garageNotificationsTitle),
        actions: [markAll],
      ),
      body: body,
    );
  }
}

/// One inbox row: a hairline-separated line with a severity stripe; unread
/// rows are bold with a dot, the time is set in the number face.
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.vehicle;
    final l = context.l10n;
    final accent = notificationSeverityColor(context, notification.severity);
    final n = notification;
    return DecoratedBox(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: t.hairline))),
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.md),
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
                              style: numberFace(15, FontWeight.w500,
                                  color: t.textSecondary)),
                          if (!n.read) ...[
                            const SizedBox(height: Spacing.sm),
                            Semantics(
                              label: l.garageUnread,
                              child: Container(
                                key: const ValueKey('unread-dot'),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: accent, shape: BoxShape.circle),
                              ),
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
    );
  }
}

/// Maximum characters of the prefilled assistant question (the server accepts
/// 500).
const int _maxQuestion = 500;

/// Question the "ask the assistant" button prefills, in the UI language.
String notificationQuestion(AppLocalizations l, AppNotification n) {
  final text = l.garageAskQuestion(n.title);
  return text.length <= _maxQuestion
      ? text
      : '${text.substring(0, _maxQuestion - 1)}…';
}

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final t = context.vehicle;
    final accent = notificationSeverityColor(context, notification.severity);
    final n = notification;
    final onAsk = NotificationScope.maybeOf(context)?.onAsk;
    return Scaffold(
      appBar: AppBar(title: Text(l.garageNotificationTitle)),
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
                Text(
                    upperFor(context, notificationSeverityLabel(l, n.severity)),
                    style: theme.textTheme.labelSmall!.copyWith(color: accent)),
                const Spacer(),
                Text(
                    '${notificationDayLabel(l, n.created)} ${notificationTime(n.created)}'
                        .trim(),
                    style: numberFace(15, FontWeight.w500,
                        color: t.textSecondary)),
              ],
            ),
            Divider(height: Spacing.xl, color: t.hairline),
            Text(n.title, style: theme.textTheme.titleLarge),
            if (n.body.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              Text(n.body, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: Spacing.xl),
            if (n.sessionId != null) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.route_outlined),
                label: Text(l.garageOpenRide),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            RideSummaryScreen(sessionId: n.sessionId!))),
              ),
              const SizedBox(height: Spacing.sm),
            ],
            if (onAsk != null)
              FilledButton.icon(
                icon: const Icon(Icons.graphic_eq),
                label: Text(l.garageAskAssistant(l.assistantName)),
                onPressed: () => onAsk(notificationQuestion(l, n), n.sessionId),
              ),
          ],
        ),
      ),
    );
  }
}
