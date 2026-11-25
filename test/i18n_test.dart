import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

Set<String> _keys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  final en = _arb('app_en.arb');
  final tr = _arb('app_tr.arb');

  test('every English key exists in Turkish and vice versa', () {
    expect(_keys(en).difference(_keys(tr)), isEmpty, reason: 'missing in tr');
    expect(_keys(tr).difference(_keys(en)), isEmpty, reason: 'extra in tr');
  });

  test('placeholders match between the languages', () {
    final re = RegExp(r'\{(\w+)\}');
    for (final key in _keys(en)) {
      final a = re.allMatches(en[key] as String).map((m) => m.group(1)).toSet();
      final b = re.allMatches(tr[key] as String).map((m) => m.group(1)).toSet();
      expect(b, a, reason: key);
    }
  });

  test('English text carries no Turkish letters', () {
    final turkish = RegExp('[çğıİöşüÇĞÖŞÜ]');
    for (final key in _keys(en)) {
      if (key == 'languageTurkish') continue;
      expect(turkish.hasMatch(en[key] as String), isFalse, reason: key);
    }
  });

  test('merged ARB files are up to date with l10n_src (run tool/l10n_merge.py)',
      () {
    final r = Process.runSync('python3', ['tool/l10n_merge.py', '--check']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });
}
