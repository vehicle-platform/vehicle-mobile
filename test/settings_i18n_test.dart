import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/l10n/locale_controller.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/auth_client.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/ui/auth/login_screen.dart';
import 'package:vehicle_mobile/ui/settings/assistant_model_screen.dart';
import 'package:vehicle_mobile/ui/settings_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/services/assistant_provider_client.dart';

import 'support/memory_secrets.dart';

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HostResolver.invalidate();
  });

  testWidgets('settings and login are localized in Turkish', (tester) async {
    final store = AppSettingsStore(secrets: MemorySecrets());
    await tester.pumpWidget(
        _app(SettingsScreen(store: store), locale: const Locale('tr')));
    await tester.pumpAndSettle();
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('HESAP'), findsOneWidget);
    expect(find.text('Giriş yapılmadı'), findsOneWidget);
    expect(find.text('SÜRÜŞ ASİSTANI'), findsOneWidget);
    expect(find.text('Cevapları sesli oku'), findsOneWidget);

    await tester.pumpWidget(
        _app(LoginScreen(store: store), locale: const Locale('tr')));
    await tester.pumpAndSettle();
    expect(find.text('Giriş yap'), findsWidgets);
    expect(find.text('Kullanıcı adı'), findsOneWidget);
  });

  testWidgets('the same screens in English show no Turkish', (tester) async {
    final store = AppSettingsStore(secrets: MemorySecrets());
    await tester.pumpWidget(_app(SettingsScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('RIDE ASSISTANT'), findsOneWidget);
    await tester.pumpWidget(_app(LoginScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('the language switch changes the locale and persists',
      (tester) async {
    final controller = LocaleController();
    final store = AppSettingsStore(secrets: MemorySecrets());
    await tester.pumpWidget(ListenableBuilder(
      listenable: controller,
      builder: (context, _) => LocaleScope(
        controller: controller,
        child: _app(SettingsScreen(store: store),
            locale: controller.override ?? const Locale('en')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Türkçe'));
    await tester.pumpAndSettle();
    expect(find.text('Ayarlar'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LocaleController.prefsKey), 'tr');
    final reloaded = await LocaleController.load();
    expect(reloaded.override?.languageCode, 'tr');
  });

  test('failure texts come from the active locale', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final tr = lookupAppLocalizations(const Locale('tr'));
    const wrong = AuthResult(AuthOutcome.unauthorized);
    expect(authFailureText(en, wrong), 'Wrong username or password.');
    expect(authFailureText(tr, wrong), 'Kullanıcı adı veya parola hatalı.');
    const limited = AuthResult(AuthOutcome.rateLimited, retryAfterSeconds: 7);
    expect(authFailureText(en, limited), contains('7 s'));
    expect(authFailureText(tr, limited), contains('7 sn'));
    expect(authFailureTextForClaim(tr, wrong), 'Oturum sona erdi.');
    expect(
        providerFailureText(
            en, const ProviderResult<Object?>(ProviderOutcome.unreachable)),
        'Could not reach the server.');
  });

  test('no Turkish literal is left in the settings, auth and shell sources',
      () {
    final turkish = RegExp('[çğıİöşüÇĞÖŞÜ]');
    final files = [
      'lib/ui/settings_screen.dart',
      'lib/ui/settings/assistant_model_screen.dart',
      'lib/ui/auth/login_screen.dart',
      'lib/ui/auth/auth_gate.dart',
      'lib/ui/app_shell.dart',
      'lib/ui/widgets/common.dart',
      ...Directory('lib/ui/shell')
          .listSync()
          .whereType<File>()
          .map((f) => f.path),
    ];
    for (final path in files) {
      expect(turkish.hasMatch(File(path).readAsStringSync()), isFalse,
          reason: path);
    }
  });
}
