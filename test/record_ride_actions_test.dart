import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_mobile/services/ble_service.dart';
import 'package:vehicle_mobile/ui/record_screen.dart';
import 'package:vehicle_mobile/ui/rides/ride_history_screen.dart';
import 'package:vehicle_mobile/ui/rides/bringup_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/widgets/common.dart';

Widget host(Widget child) => MaterialApp(theme: buildAppTheme(), home: child);

Future<void> seedSession(
  Directory tmp,
  String sessionId, {
  required String uploadState,
  String? uploadedAtUtc,
}) async {
  final dir = Directory('${tmp.path}/sessions/$sessionId');
  await dir.create(recursive: true);
  await File('${dir.path}/meta.json').writeAsString(jsonEncode({
    'session_id': sessionId,
    'created_utc': '2026-01-15T12:00:00Z',
  }));
  await File('${dir.path}/summary.json').writeAsString(jsonEncode({
    'duration_ms': 1000,
    'packet_count': 5,
    'loss_percent': 0.0,
  }));
  await File('${dir.path}/upload.json').writeAsString(jsonEncode({
    'state': uploadState,
    'uploaded_at_utc': uploadedAtUtc,
  }));
}

/// Pumps real-time event-loop turns until [finder] matches. The screen loads
/// its session folders with real file IO, which only completes inside
/// `runAsync`; waiting on the visible result instead of a fixed delay keeps the
/// test independent of machine load.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $finder');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    // Advance fake time too so the tab animation can finish.
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens the Sessions tab and waits until every id in [sessionIds] is listed.
/// The settings load (mocked prefs and secure storage, no file IO) is started
/// before the folder scan and ends first, so the last drain below only covers
/// event-loop turns that are already queued.
Future<void> openSessionsTab(
  WidgetTester tester,
  List<String> sessionIds,
) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Built inside `runAsync` so the screen's initState IO runs in the real zone.
  await tester.runAsync(() async {
    await tester.pumpWidget(host(RecordScreen(bleService: BleService())));
  });
  await tester.pump();
  await tester.tap(find.text('Sessions'));
  await tester.pump(const Duration(milliseconds: 300));
  for (final id in sessionIds) {
    await pumpUntilFound(tester, find.text(id));
  }
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void main() {
  late Directory tmp;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    tmp = Directory.systemTemp.createTempSync('record_ride_actions_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets(
      'Ride summary appears only for an uploaded session with a configured server',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.server_base_url': 'https://server.example',
    });
    await tester.runAsync(() async {
      await seedSession(
        tmp,
        '20260116-120000-ab12',
        uploadState: 'uploaded',
        uploadedAtUtc: '2026-01-16T12:00:00Z',
      );
      await seedSession(tmp, '20260115-120000-ab12',
          uploadState: 'notUploaded');
    });

    await openSessionsTab(
        tester, ['20260116-120000-ab12', '20260115-120000-ab12']);

    expect(find.byTooltip('Server rides'), findsOneWidget);

    final uploadedCard = find.ancestor(
      of: find.text('20260116-120000-ab12'),
      matching: find.byType(SectionCard),
    );
    expect(
      find.descendant(
          of: uploadedCard, matching: find.byTooltip('Ride summary')),
      findsOneWidget,
    );

    final notUploadedCard = find.ancestor(
      of: find.text('20260115-120000-ab12'),
      matching: find.byType(SectionCard),
    );
    expect(
      find.descendant(
          of: notUploadedCard, matching: find.byTooltip('Ride summary')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Ride summary is hidden without a configured server; Server rides still opens',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await seedSession(
        tmp,
        '20260116-120000-ab12',
        uploadState: 'uploaded',
        uploadedAtUtc: '2026-01-16T12:00:00Z',
      );
    });

    await openSessionsTab(tester, ['20260116-120000-ab12']);

    expect(find.byTooltip('Ride summary'), findsNothing);

    await tester.tap(find.byTooltip('Server rides'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(RideHistoryScreen), findsOneWidget);
    expect(
      find.text(
          'No vehicle-server configured. Set the server URL and API token in Settings.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Bring-up check appears only for an uploaded session and opens that id',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.server_base_url': 'https://server.example',
    });
    await tester.runAsync(() async {
      await seedSession(
        tmp,
        '20260116-120000-ab12',
        uploadState: 'uploaded',
        uploadedAtUtc: '2026-01-16T12:00:00Z',
      );
      await seedSession(tmp, '20260115-120000-ab12',
          uploadState: 'notUploaded');
      await seedSession(tmp, '20260114-120000-ab12', uploadState: 'failed');
    });

    await openSessionsTab(tester, [
      '20260116-120000-ab12',
      '20260115-120000-ab12',
      '20260114-120000-ab12',
    ]);

    final uploadedCard = find.ancestor(
      of: find.text('20260116-120000-ab12'),
      matching: find.byType(SectionCard),
    );
    expect(
      find.descendant(
          of: uploadedCard, matching: find.byTooltip('Bring-up check')),
      findsOneWidget,
    );
    for (final id in ['20260115-120000-ab12', '20260114-120000-ab12']) {
      final card = find.ancestor(
        of: find.text(id),
        matching: find.byType(SectionCard),
      );
      expect(
        find.descendant(of: card, matching: find.byTooltip('Bring-up check')),
        findsNothing,
      );
    }

    final bringupButton = find.descendant(
      of: uploadedCard,
      matching: find.byIcon(Icons.fact_check_outlined),
    );
    await tester.ensureVisible(bringupButton);
    await tester.pumpAndSettle();
    await tester.tap(bringupButton);
    await tester.pumpAndSettle();

    expect(find.byType(BringupScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BringupScreen),
        matching: find.text('20260116-120000-ab12'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
  });
}
