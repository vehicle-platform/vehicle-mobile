import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/models/host.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/ui/settings_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

import 'support/memory_secrets.dart';

Future<(AppSettingsStore, MemorySecrets)> _pump(WidgetTester tester,
    {List<Host> hosts = const []}) async {
  SharedPreferences.setMockInitialValues({});
  HostResolver.invalidate();
  final secrets = MemorySecrets();
  final store = AppSettingsStore(secrets: secrets);
  await store.hosts.saveHosts(hosts);
  await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: SettingsScreen(store: store)));
  await tester.pumpAndSettle();
  return (store, secrets);
}

void main() {
  testWidgets(
      'adds a host: URL and name in the list, token only in secure storage',
      (tester) async {
    final (store, secrets) = await _pump(tester);
    expect(find.textContaining('No host configured yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Add host'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Bike');
    await tester.enterText(find.widgetWithText(TextField, 'Server base URL'),
        'http://192.168.1.20:8000');
    await tester.enterText(
        find.widgetWithText(TextField, 'Device token'), 'secret');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final hosts = await store.hosts.load();
    expect(hosts.single.name, 'Bike');
    expect(secrets.values, {'host.${hosts.single.id}.token': 'secret'});
    expect(find.text('Bike'), findsOneWidget);
    expect(find.text('token set'), findsOneWidget);
    expect(find.text('secret'), findsNothing);
    expect(find.text('ACTIVE'),
        findsNothing); // pill text is not upper-cased by the widget
    expect(find.text('active'), findsOneWidget);
  });

  testWidgets(
      'refuses a host the token could never be sent to (public plain http)',
      (tester) async {
    final (store, _) = await _pump(tester);
    await tester.tap(find.byTooltip('Add host'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Remote');
    await tester.enterText(find.widgetWithText(TextField, 'Server base URL'),
        'http://203.0.113.9:8000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining(
            'Refusing to send the API token over plain http://'),
        findsOneWidget);
    expect(await store.hosts.load(), isEmpty);
  });

  testWidgets('deleting a host removes its token', (tester) async {
    final (store, secrets) = await _pump(
      tester,
      hosts: const [
        Host(id: 'a', name: 'Remote', baseUrl: 'https://r.example.com')
      ],
    );
    await store.hosts.writeToken('a', 'tok');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(), home: SettingsScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete host'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await store.hosts.load(), isEmpty);
    expect(secrets.values, isEmpty);
  });

  testWidgets('reordering persists the new priority order', (tester) async {
    final (store, _) = await _pump(tester, hosts: const [
      Host(id: 'a', name: 'Local', baseUrl: 'http://10.0.0.5:8000'),
      Host(id: 'b', name: 'Remote', baseUrl: 'https://r.example.com'),
    ]);
    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect((await store.hosts.load()).map((h) => h.id), ['b', 'a']);
  });
}
