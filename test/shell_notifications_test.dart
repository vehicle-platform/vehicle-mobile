import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/services/auth_client.dart';
import 'package:vehicle_mobile/services/notifications/local_notifier.dart';
import 'package:vehicle_mobile/services/notifications/notification_center.dart';
import 'package:vehicle_mobile/services/notifications/notification_sync.dart';
import 'package:vehicle_mobile/services/notifications_client.dart';
import 'package:vehicle_mobile/ui/app_shell.dart';
import 'package:vehicle_mobile/ui/assistant/assistant_screen.dart';
import 'package:vehicle_mobile/ui/notifications/notifications_screen.dart';
import 'package:vehicle_mobile/ui/settings_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';

import 'support/signed_in.dart';

Map<String, Object?> _note(int id,
        {String severity = 'info',
        String kind = 'ride_summary',
        bool read = false,
        String? session,
        DateTime? created}) =>
    {
      'id': id,
      'vehicle_id': 'veh-1',
      'kind': kind,
      'severity': severity,
      'title': 'Başlık $id',
      'body': 'Gövde $id',
      'session_id': session,
      'fault_id': null,
      'created_utc': (created ?? DateTime.now()).toUtc().toIso8601String(),
      'read': read,
    };

NotificationCenter _center(List<Map<String, Object?>> items,
    {int status = 200, void Function(http.Request)? onRequest}) {
  final store = signedInStore();
  return NotificationCenter(
    pollInterval: const Duration(hours: 1),
    sync: NotificationSync(
      settingsStore: store,
      client: NotificationsClient(httpClient: MockClient((req) async {
        onRequest?.call(req);
        if (status != 200) return http.Response('nf', status);
        if (req.method == 'POST') return http.Response('', 204);
        return http.Response(
            jsonEncode({'notifications': items, 'latest_id': items.length}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      })),
    ),
  );
}

Future<void> _size(WidgetTester tester, double w, double h) async {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _shell(NotificationCenter center) => MaterialApp(
      theme: buildAppTheme(),
      home: AppShell(
        settingsStore: center.sync.settingsStore,
        notifications: center,
        localNotifier: const NoopLocalNotifier(),
        backgroundPull: false,
      ),
    );

void main() {
  group('responsive layout by width', () {
    testWidgets('390x844: bottom bar, full-width content, 16 px gutters',
        (tester) async {
      await _size(tester, 390, 844);
      await tester.pumpWidget(_shell(_center([])));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      final composer = tester.getRect(find.byType(AssistantComposer));
      expect(composer.width, 390);
      // The input pill starts at the 16 px gutter.
      final pill = tester.getRect(find
          .descendant(
              of: find.byType(AssistantComposer),
              matching: find.byType(Material))
          .first);
      expect(pill.left, Spacing.lg);
      expect(pill.right, 390 - Spacing.lg);
      expect(tester.takeException(), isNull);
    });

    testWidgets('800x1000: navigation rail, no bottom bar', (tester) async {
      await _size(tester, 800, 1000);
      await tester.pumpWidget(_shell(_center([])));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1440x900: rail and an assistant column of at most 720 px',
        (tester) async {
      await _size(tester, 1440, 900);
      await tester.pumpWidget(_shell(_center([])));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      final composer = tester.getRect(find.byType(AssistantComposer));
      expect(composer.width, lessThanOrEqualTo(ContentWidth.assistant));
      // Centred in the area right of the rail.
      final rail = tester.getRect(find.byType(NavigationRail));
      final area = (rail.right + 1440) / 2;
      expect(composer.center.dx, closeTo(area, 1));
    });

    testWidgets('settings column is at most 960 px wide on a big window',
        (tester) async {
      await _size(tester, 1440, 900);
      await tester.pumpWidget(_shell(_center([])));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(NavigationRail), matching: find.text('Settings')));
      await tester.pumpAndSettle();
      final screen = tester.getRect(find.byType(SettingsScreen));
      expect(screen.width, greaterThan(ContentWidth.list));
      final card = tester.getRect(find.byType(SectionCard).first);
      expect(card.width, lessThanOrEqualTo(ContentWidth.list - 2 * Spacing.lg));
      expect(card.center.dx, closeTo(screen.center.dx, 1));
    });

    testWidgets('a narrow window below 600 px uses the mobile layout',
        (tester) async {
      await _size(tester, 599, 800);
      await tester.pumpWidget(_shell(_center([])));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await _size(tester, 600, 800);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });

  group('rename', () {
    testWidgets('tab label, screen title and greeting say Sürüş Asistanı',
        (tester) async {
      await _size(tester, 390, 844);
      await tester.pumpWidget(_shell(_center([])));
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(NavigationBar), matching: find.text('Assistant')),
          findsOneWidget);
      expect(find.text('Sürüş Asistanı'), findsOneWidget); // app bar title
      expect(find.text('Merhaba, ben Sürüş Asistanı. Ne öğrenmek istersin?'),
          findsOneWidget);
      expect(find.textContaining('Usta'), findsNothing);
    });

    testWidgets('settings section is named Sürüş Asistanı', (tester) async {
      await _size(tester, 390, 2000);
      await tester.pumpWidget(_shell(_center([])));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('SÜRÜŞ ASISTANI'), findsOneWidget);
      expect(find.textContaining('Usta'), findsNothing);
    });
  });

  group('notifications', () {
    testWidgets('bell shows the unread count and the inbox groups by day',
        (tester) async {
      await _size(tester, 390, 844);
      final now = DateTime.now();
      final center = _center([
        _note(1, created: now.subtract(const Duration(days: 1))),
        _note(2, severity: 'critical', kind: 'fault'),
        _note(3, read: true, severity: 'warning'),
      ]);
      await tester.pumpWidget(_shell(center));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget); // unread badge

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Bildirimler'), findsOneWidget);
      expect(find.text('BUGÜN'), findsOneWidget);
      expect(find.text('DÜN'), findsOneWidget);
      expect(find.text('Başlık 2'), findsOneWidget);
      // Newest first within the day.
      expect(tester.getTopLeft(find.text('Başlık 3')).dy,
          lessThan(tester.getTopLeft(find.text('Başlık 2')).dy));
      expect(find.byKey(const ValueKey('unread-dot')), findsNWidgets(2));
    });

    testWidgets('"Tümünü okundu say" clears the badge and posts read-all',
        (tester) async {
      await _size(tester, 390, 844);
      final calls = <String>[];
      final center = _center([_note(1), _note(2)],
          onRequest: (r) => calls.add('${r.method} ${r.url.path}'));
      await tester.pumpWidget(_shell(center));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tümünü okundu say'));
      await tester.pumpAndSettle();
      expect(center.unreadCount, 0);
      expect(calls, contains('POST /notifications/read-all'));
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
    });

    testWidgets('an old server (404) hides the bell quietly', (tester) async {
      await _size(tester, 390, 844);
      await tester.pumpWidget(_shell(_center([], status: 404)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detail: ride link, ask the assistant prefilled with the ride',
        (tester) async {
      await _size(tester, 390, 844);
      final center = _center([_note(7, session: 'sess-1')]);
      await tester.pumpWidget(_shell(center));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Başlık 7'));
      await tester.pumpAndSettle();
      expect(find.text('Gövde 7'), findsOneWidget);
      expect(find.text('Sürüşü aç'), findsOneWidget);
      expect(center.unreadCount, 0); // opening marks it read

      await tester.tap(find.text("Sürüş Asistanı'na sor"));
      await tester.pumpAndSettle();
      // Back in the shell on the assistant tab, question prefilled, not sent.
      expect(find.byType(NotificationDetailScreen), findsNothing);
      final field = tester.widget<TextField>(find.descendant(
          of: find.byType(AssistantComposer),
          matching: find.byType(TextField)));
      expect(field.controller!.text, contains('Başlık 7'));
      expect(find.text('Ride sess-1'), findsOneWidget);
    });

    testWidgets('empty inbox shows a compact empty state', (tester) async {
      await _size(tester, 390, 844);
      final center = _center([]);
      await tester.pumpWidget(_shell(center));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Henüz bildirim yok'), findsOneWidget);
    });
  });

  group('settings account section', () {
    testWidgets('shows user, vehicles and logs out through the server',
        (tester) async {
      await _size(tester, 390, 1000);
      final store = signedInStore();
      final calls = <String>[];
      final auth = AuthClient(httpClient: MockClient((r) async {
        calls.add('${r.method} ${r.url.path} ${r.headers['Authorization']}');
        return http.Response('', 204);
      }));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'auth.h1.account',
          jsonEncode({
            'username': 'rider',
            'vehicles': [
              {'vehicle_id': 'veh-1', 'name': 'CL250'}
            ]
          }));
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: SettingsScreen(store: store, authClient: auth),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Giriş yapan: rider'), findsOneWidget);
      expect(find.text('CL250'), findsOneWidget);
      expect(find.text('Araç ekle'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('logout')));
      await tester.pumpAndSettle();
      expect(calls, ['POST /auth/logout Bearer tok']);
      expect(find.text('Giriş yapılmadı'), findsOneWidget);
    });
  });
}
