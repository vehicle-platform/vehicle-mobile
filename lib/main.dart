import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/l10n/locale_controller.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/ui/app_shell.dart';
import 'package:vehicle_mobile/ui/auth/auth_gate.dart';
import 'package:vehicle_mobile/ui/phone/phone_tabs.dart';
import 'package:vehicle_mobile/ui/phone/phone_tabs_factory.dart';
import 'package:vehicle_mobile/ui/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final locale = await LocaleController.load();
  final theme = await ThemeController.load();
  runApp(Cl250TelemetryApp(localeController: locale, themeController: theme));
}

class Cl250TelemetryApp extends StatelessWidget {
  Cl250TelemetryApp(
      {super.key,
      PhoneTabs? phoneTabs,
      this.settingsStore = const AppSettingsStore(),
      LocaleController? localeController,
      ThemeController? themeController})
      : phoneTabs = phoneTabs ?? createPhoneTabs(),
        localeController = localeController ?? LocaleController(),
        themeController = themeController ?? ThemeController();

  /// The language choice (English default, Turkish selectable, D-125).
  final LocaleController localeController;

  /// The display choice: system (dark first), dark, light or sunlight.
  final ThemeController themeController;

  /// Where the login gate reads the host and its session (tests inject one).
  final AppSettingsStore settingsStore;

  /// Phone-only destinations (BLE telemetry, recording, diagnostics), shared
  /// by every screen so recording captures the same live connection the Live
  /// and Signals screens show. Null on web and desktop (D-121 item 3).
  final PhoneTabs? phoneTabs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([localeController, themeController]),
      builder: (context, _) => LocaleScope(
        controller: localeController,
        child: ThemeScope(controller: themeController, child: _app()),
      ),
    );
  }

  Widget _app() {
    return MaterialApp(
      title: 'CL250 Telemetry',
      locale: localeController.override ?? const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: themeController.lightTheme,
      darkTheme: themeController.darkTheme,
      // Dark first; "system" follows the system setting, sunlight is the
      // daylight variant of the light theme.
      themeMode: themeController.themeMode,
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
