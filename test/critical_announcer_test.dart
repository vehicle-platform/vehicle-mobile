import 'package:flutter_test/flutter_test.dart';

import 'package:vehicle_mobile/services/voice/critical_announcer.dart';

void main() {
  test('advise_stop speaks the fixed Turkish sentence', () async {
    final spoken = <String>[];
    final announcer = CriticalAnnouncer(speak: (s) async => spoken.add(s));
    expect(await announcer.announce(const AdviseStopEvent()), isTrue);
    expect(spoken, ['Güvenli bir yerde dur ve motoru kontrol ettir.']);
  });

  test('a high-severity fault is announced once per id with the server title',
      () async {
    final spoken = <String>[];
    final announcer = CriticalAnnouncer(speak: (s) async => spoken.add(s));
    const event = HighSeverityFaultEvent(
        id: 'F-1', title: 'Soğutma sıvısı sıcaklığı yüksek');
    expect(await announcer.announce(event), isTrue);
    expect(await announcer.announce(event), isFalse);
    expect(spoken, hasLength(1));
    expect(spoken.single, contains('Soğutma sıvısı sıcaklığı yüksek'));
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
}
