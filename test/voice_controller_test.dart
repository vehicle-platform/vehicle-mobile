import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/services/voice/intercom_audio.dart';
import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/services/voice/voice_settings.dart';

import 'support/fake_voice.dart';

VoiceController _controller(
  FakeRecognizer stt,
  FakeOutput tts, {
  IntercomAudio? intercom,
  List<String>? transcripts,
  List<String>? log,
}) {
  final c = VoiceController(
    recognizer: stt,
    output: tts,
    intercom: intercom ?? IntercomAudio(supported: false),
    ensureBluetoothPermission: () async => log?.add('bt-permission'),
    finalWait: const Duration(milliseconds: 5),
  );
  c.onTranscript = (t) => transcripts?.add(t);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(
      {VoiceSettings.keyReadAnswers: true}));

  test('mic flow: idle -> listening -> partials -> final sends the transcript',
      () async {
    final stt = FakeRecognizer();
    final sent = <String>[];
    final c = _controller(stt, FakeOutput(), transcripts: sent);
    expect(c.state, VoiceState.idle);
    await c.toggleMic();
    expect(c.state, VoiceState.listening);
    expect(stt.initializeCalls, 1);
    stt.partial('son sürü');
    expect(c.partial, 'son sürü');
    stt.finalResult('son sürüşüm nasıldı');
    await Future<void>.delayed(Duration.zero);
    expect(c.state, VoiceState.idle);
    expect(sent, ['son sürüşüm nasıldı']);
    expect(c.partial, isEmpty);
  });

  test('second tap stops listening and sends the transcript so far', () async {
    final stt = FakeRecognizer();
    final sent = <String>[];
    final c = _controller(stt, FakeOutput(), transcripts: sent);
    await c.toggleMic();
    stt.partial('kayıtlı arızalar');
    await c.toggleMic();
    expect(stt.stopCalls, 1);
    expect(c.state, VoiceState.idle);
    expect(sent, ['kayıtlı arızalar']);
  });

  test('status done without a result ends the session with the partial text',
      () async {
    final stt = FakeRecognizer();
    final sent = <String>[];
    final c = _controller(stt, FakeOutput(), transcripts: sent);
    await c.startListening();
    stt.partial('merhaba usta');
    stt.status('done');
    await Future<void>.delayed(Duration.zero);
    expect(sent, ['merhaba usta']);
  });

  test(
      'silence gives the friendly "could not hear you" message and sends nothing',
      () async {
    final stt = FakeRecognizer();
    final sent = <String>[];
    final c = _controller(stt, FakeOutput(), transcripts: sent);
    await c.startListening();
    stt.error('error_speech_timeout');
    expect(c.state, VoiceState.idle);
    expect(c.error, voiceNoSpeechMessage);
    expect(sent, isEmpty);
  });

  test('unavailable recognition or a denied permission gives a Turkish message',
      () async {
    final stt = FakeRecognizer()..initializeResult = false;
    final c = _controller(stt, FakeOutput());
    await c.startListening();
    expect(c.state, VoiceState.idle);
    expect(c.error, voicePermissionMessage);
    c.clearError();
    expect(c.error, isNull);

    final stt2 = FakeRecognizer();
    final c2 = _controller(stt2, FakeOutput());
    await c2.startListening();
    stt2.error('error_language_unavailable');
    expect(c2.error, voiceLanguageMessage);
    await c2.startListening();
    stt2.error('error_network');
    expect(c2.error, voiceNetworkMessage);
  });

  test('speak reads the text when the setting is on and skips it when off',
      () async {
    final tts = FakeOutput()..instant = true;
    final c = _controller(FakeRecognizer(), tts);
    expect(await c.speak('Cevap'), isTrue);
    expect(tts.spoken, ['Cevap']);
    SharedPreferences.setMockInitialValues(
        {VoiceSettings.keyReadAnswers: false});
    expect(await c.speak('Sessiz'), isFalse);
    expect(tts.spoken, ['Cevap']);
    expect(await c.speak('Tekrar', force: true), isTrue);
    expect(tts.spoken, ['Cevap', 'Tekrar']);
  });

  test('stopSpeaking silences the answer; the interrupted speak reports false',
      () async {
    final tts = FakeOutput();
    final c = _controller(FakeRecognizer(), tts);
    final spoke = c.speak('Uzun cevap');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.state, VoiceState.speaking);
    await c.stopSpeaking();
    expect(await spoke, isFalse);
    expect(tts.stopCalls, 1);
    expect(c.state, VoiceState.idle);
  });

  test('tapping the mic while speaking stops the speech and starts listening',
      () async {
    final tts = FakeOutput();
    final stt = FakeRecognizer();
    final c = _controller(stt, tts);
    final spoke = c.speak('Cevap');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await c.toggleMic();
    expect(tts.stopCalls, greaterThan(0));
    expect(c.state, VoiceState.listening);
    expect(await spoke, isFalse);
  });

  group('intercom routing', () {
    test('a connected headset is routed before listening and released after',
        () async {
      final log = <String>[];
      final intercom = FakeIntercom();
      final stt = FakeRecognizer();
      final c =
          _controller(stt, FakeOutput(), intercom: intercom.audio, log: log);
      await c.refreshIntercom();
      expect(c.routeLabel, intercomConnectedLabel);
      await c.startListening();
      expect(log, contains('bt-permission'));
      expect(intercom.calls, containsAllInOrder(['status', 'acquire']));
      stt.finalResult('soru');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(intercom.calls.last, 'release');
    });

    test('speech is routed through the intercom and released afterwards',
        () async {
      final intercom = FakeIntercom();
      final tts = FakeOutput()..instant = true;
      final c = _controller(FakeRecognizer(), tts, intercom: intercom.audio);
      await c.speak('Cevap');
      expect(tts.viaIntercom, [true]);
      expect(intercom.calls, containsAllInOrder(['acquire', 'release']));
    });

    test('without a headset the phone mic and speaker are used', () async {
      final intercom = FakeIntercom(headset: false);
      final tts = FakeOutput()..instant = true;
      final c = _controller(FakeRecognizer(), tts, intercom: intercom.audio);
      await c.refreshIntercom();
      expect(c.routeLabel, phoneMicLabel);
      await c.speak('Cevap');
      expect(tts.viaIntercom, [false]);
      expect(intercom.calls, isNot(contains('release')));
    });

    test('no routing label off Android', () async {
      final c = _controller(FakeRecognizer(), FakeOutput());
      expect(c.routeLabel, isNull);
    });
  });
}
