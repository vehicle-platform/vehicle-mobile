import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/ui/app_shell.dart';
import 'package:vehicle_mobile/ui/auth/auth_gate.dart';
import 'package:vehicle_mobile/ui/phone/phone_tabs.dart';
import 'package:vehicle_mobile/ui/phone/phone_tabs_factory.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

void main() {
  runApp(Cl250TelemetryApp());
}

class Cl250TelemetryApp extends StatelessWidget {
  Cl250TelemetryApp(
      {super.key, PhoneTabs? phoneTabs, this.settingsStore = const AppSettingsStore()})
      : phoneTabs = phoneTabs ?? createPhoneTabs();

  /// Where the login gate reads the host and its session (tests inject one).
  final AppSettingsStore settingsStore;

  /// Phone-only destinations (BLE telemetry, recording, diagnostics), shared
  /// by every screen so recording captures the same live connection the Live
  /// and Signals screens show. Null on web and desktop (D-121 item 3).
  final PhoneTabs? phoneTabs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CL250 Telemetry',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(),
      // Dark first; the light theme follows the system setting.
      themeMode: ThemeMode.system,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: child!,
      ),
      // D-122: the app opens once the active host has a session. The phone
      // may skip the login (BLE and recording need no server).
      home: AuthGate(
        store: settingsStore,
        allowSkip: phoneTabs != null,
        builder: (_) => AppShell(phoneTabs: phoneTabs),
      ),
    );
  }
}
