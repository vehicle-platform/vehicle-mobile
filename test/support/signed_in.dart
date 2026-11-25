import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/host_store.dart';

import 'memory_secrets.dart';

/// A settings store with one host (`h1`, [baseUrl]) that already holds a
/// session token, plus matching mock preferences. Call inside a test or
/// `setUp`.
AppSettingsStore signedInStore({
  MemorySecrets? secrets,
  String baseUrl = 'https://vehicle.example.test',
  String token = 'tok',
  Map<String, Object> extraPrefs = const {},
}) {
  final memory = secrets ?? MemorySecrets();
  memory.values[HostStore.tokenKey('h1')] = token;
  SharedPreferences.setMockInitialValues({
    'hosts.v1': jsonEncode([
      {'id': 'h1', 'name': 'Test', 'base_url': baseUrl}
    ]),
    ...extraPrefs,
  });
  return AppSettingsStore(secrets: memory);
}
