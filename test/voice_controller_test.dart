import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/services/voice/intercom_audio.dart';
import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/services/voice/voice_ports.dart';
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
    ensureMicrophonePermission: () async {},
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

  test('speech language follows the app language (en-US default, tr-TR)',
      () async {
    expect(voiceTagFor('en'), 'en-US');
    expect(voiceTagFor('tr'), 'tr-TR');
    expect(voiceTagFor('de'), 'en-US');

    final stt = FakeRecognizer();
    final tts = FakeOutput()..instant = true;
    final c = _controller(stt, tts);
    expect(c.localeTag, 'en-US');
    await c.toggleMic();
    stt.finalResult('last ride');
    await Future<void>.delayed(Duration.zero);
    await c.speak('Answer');
    expect(stt.listenLocales, ['en-US']);
    expect(tts.localeTags, ['en-US']);

    // The shell switches the tag when the language changes; the next listen
    // and the next voice use it.
    c.localeTag = voiceTagFor('tr');
    await c.toggleMic();
    stt.finalResult('recorded faults');
    await Future<void>.delayed(Duration.zero);
    await c.speak('Answer');
    expect(stt.listenLocales, ['en-US', 'tr-TR']);
    expect(tts.localeTags, ['en-US', 'tr-TR']);
  });

  test('mic flow: idle -> listening -> partials -> final sends the transcript',
      () async {
    final stt = FakeRecognizer();
    final sent = <String>[];
    final c = _controller(stt, FakeOutput(), transcripts: sent);
    expect(c.state, VoiceState.idle);
    await c.toggleMic();
    expect(c.state, VoiceState.listening);
    expect(stt.initializeCalls, 1);
    stt.partial('my last ri');
    expect(c.partial, 'my last ri');
    stt.finalResult('how was my last ride');
    await Future<void>.delayed(Duration.zero);
    expect(c.state, VoiceState.idle);
    expect(sent, ['how was my last ride']);
    expect(c.partial, isEmpty);
  });

  test('second tap stops listening and sends the transcript so far', () async {
    final stt = FakeRecognizer();
    final sent = <String>[];
    final c = _controller(stt, FakeOutput(), transcripts: sent);
    await c.toggleMic();
    stt.partial('recorded faults');
    await c.toggleMic();
    expect(stt.stopCalls, 1);
    expect(c.state, VoiceState.idle);
    expect(sent, ['recorded faults']);
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
    expect(c.error, VoiceError.noSpeech);
    expect(sent, isEmpty);
  });

  test('unavailable recognition or a denied permission gives an error code',
      () async {
    final stt = FakeRecognizer()..initializeResult = false;
    final c = _controller(stt, FakeOutput());
    await c.startListening();
    expect(c.state, VoiceState.idle);
    expect(c.error, VoiceError.permission);
    c.clearError();
    expect(c.error, isNull);

    final stt2 = FakeRecognizer();
    final c2 = _controller(stt2, FakeOutput());
    await c2.startListening();
    stt2.error('error_language_unavailable');
    expect(c2.error, VoiceError.language);
    await c2.startListening();
    stt2.error('error_network');
    expect(c2.error, VoiceError.network);
  });

  test('speak reads the text when the setting is on and skips it when off',
      () async {
    final tts = FakeOutput()..instant = true;
    final c = _controller(FakeRecognizer(), tts);
    expect(await c.speak('Answer'), isTrue);
    expect(tts.spoken, ['Answer']);
    SharedPreferences.setMockInitialValues(
        {VoiceSettings.keyReadAnswers: false});
    expect(await c.speak('Silent'), isFalse);
    expect(tts.spoken, ['Answer']);
    expect(await c.speak('Again', force: true), isTrue);
    expect(tts.spoken, ['Answer', 'Again']);
  });

  test('stopSpeaking silences the answer; the interrupted speak reports false',
      () async {
    final tts = FakeOutput();
    final c = _controller(FakeRecognizer(), tts);
    final spoke = c.speak('Long answer');
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
    final spoke = c.speak('Answer');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await c.toggleMic();
    expect(tts.stopCalls, greaterThan(0));
    expect(c.state, VoiceState.listening);
    expect(await spoke, isFalse);
  });

  group('recogniser start timeout', () {
    test(
        'a hanging initialize resets to idle with the init-timeout error after the permission step',
        () async {
      final order = <String>[];
      final stt = FakeRecognizer()..initializeHangs = true;
      final c = VoiceController(
        recognizer: stt,
        output: FakeOutput(),
        intercom: IntercomAudio(supported: false),
        ensureMicrophonePermission: () async {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          order.add('permission-done');
        },
        initTimeout: const Duration(milliseconds: 20),
      );
      await c.startListening();
      expect(order, ['permission-done']); // the permission step is not bounded
      expect(c.state, VoiceState.idle);
      expect(c.error, VoiceError.initTimeout);
      expect(c.isListening, isFalse);
    });
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
      expect(c.route, VoiceRoute.intercom);
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
      await c.speak('Answer');
      expect(tts.viaIntercom, [true]);
      expect(intercom.calls, containsAllInOrder(['acquire', 'release']));
    });

    test('without a headset the phone mic and speaker are used', () async {
      final intercom = FakeIntercom(headset: false);
      final tts = FakeOutput()..instant = true;
      final c = _controller(FakeRecognizer(), tts, intercom: intercom.audio);
      await c.refreshIntercom();
      expect(c.route, VoiceRoute.phone);
      await c.speak('Answer');
      expect(tts.viaIntercom, [false]);
      expect(intercom.calls, isNot(contains('release')));
    });

    test('no routing label off Android', () async {
      final c = _controller(FakeRecognizer(), FakeOutput());
      expect(c.route, isNull);
    });
  });
}
