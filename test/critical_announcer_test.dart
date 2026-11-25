import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

import 'package:vehicle_mobile/l10n/app_localizations.dart';
import 'package:vehicle_mobile/services/voice/critical_announcer.dart';

void main() {
  test('advise_stop speaks the fixed English sentence by default', () async {
    final spoken = <String>[];
    final announcer = CriticalAnnouncer(speak: (s) async => spoken.add(s));
    expect(await announcer.announce(const AdviseStopEvent()), isTrue);
    expect(spoken, ['Stop in a safe place and have the engine checked.']);
  });

  test('a high-severity fault is announced once per id with the server title',
      () async {
    final spoken = <String>[];
    final announcer = CriticalAnnouncer(speak: (s) async => spoken.add(s));
    const event = HighSeverityFaultEvent(
        id: 'F-1', title: 'Coolant temperature high');
    expect(await announcer.announce(event), isTrue);
    expect(await announcer.announce(event), isFalse);
    expect(spoken, hasLength(1));
    expect(spoken.single, contains('Coolant temperature high'));
    expect(spoken.single, endsWith(CriticalAnnouncer.adviseStopSentence));
    announcer.reset();
    expect(await announcer.announce(event), isTrue);
  });

  test('resultAdvisesStop finds advise_stop true at any depth, only when true',
      () {
    expect(CriticalAnnouncer.resultAdvisesStop({'advise_stop': true}), isTrue);
    expect(
        CriticalAnnouncer.resultAdvisesStop({
          'entries': [
            {'id': 'a', 'advise_stop': false},
            {
              'id': 'b',
              'detail': {'advise_stop': true}
            },
          ]
        }),
        isTrue);
    expect(
        CriticalAnnouncer.resultAdvisesStop({'advise_stop': 'true'}), isFalse);
    expect(
        CriticalAnnouncer.resultAdvisesStop({'advise_stop': false}), isFalse);
    expect(CriticalAnnouncer.resultAdvisesStop(null), isFalse);
    expect(CriticalAnnouncer.resultAdvisesStop('advise_stop'), isFalse);
  });

  test('the sentences follow the provider (active locale)', () async {
    final spoken = <String>[];
    var l = lookupAppLocalizations(const Locale('en'));
    final announcer = CriticalAnnouncer(
        speak: (s) async => spoken.add(s),
        sentences: () => AnnouncerSentences.fromL10n(l));
    await announcer.announce(const AdviseStopEvent());
    l = lookupAppLocalizations(const Locale('tr'));
    await announcer.announce(const AdviseStopEvent());
    await announcer
        .announce(const HighSeverityFaultEvent(id: 'F-2', title: 'Sıcaklık'));
    expect(spoken[0], 'Stop in a safe place and have the engine checked.');
    expect(spoken[1], 'Güvenli bir yerde dur ve motoru kontrol ettir.');
    expect(spoken[2], startsWith('Yüksek öncelikli uyarı: Sıcaklık.'));
  });
}
