import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_mobile/models/host.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/chat_client.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/services/voice/critical_announcer.dart';
import 'package:vehicle_mobile/services/voice/intercom_audio.dart';
import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/services/voice/voice_settings.dart';
import 'package:vehicle_mobile/services/voice/voice_triggers.dart';
import 'package:vehicle_mobile/ui/app_shell.dart';
import 'package:vehicle_mobile/ui/assistant/assistant_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

import 'support/fake_voice.dart';
import 'support/memory_secrets.dart';

const _host = Host(id: 'h1', name: 'Bike', baseUrl: 'https://bike.example.com');

http.Response _answer(String text, {Object? result}) => http.Response(
    jsonEncode({
      'answer': text,
      'source': 'llm',
      'tool': {'name': 'get_fault', 'arguments': {}},
      'result': result,
    }),
    200,
    headers: {'content-type': 'application/json'});

Future<AppSettingsStore> _store({bool readAnswers = true}) async {
  SharedPreferences.setMockInitialValues(
      {VoiceSettings.keyReadAnswers: readAnswers});
  HostResolver.invalidate();
  final store = AppSettingsStore(secrets: MemorySecrets());
  await store.hosts.saveHosts([_host]);
  await store.hosts.writeToken('h1', 'tok');
  return store;
}

class _Rig {
  _Rig(this.tester, this.store, this.client, this.stt, this.tts, this.voice,
      this.bus);
  final WidgetTester tester;
  final AppSettingsStore store;
  final ChatClient client;
  final FakeRecognizer stt;
  final FakeOutput tts;
  final VoiceController voice;
  final VoiceTriggerBus bus;
}

Future<_Rig> _pump(
  WidgetTester tester, {
  required http.Response Function() reply,
  bool readAnswers = true,
  bool instantSpeech = true,
  List<String>? asked,
}) async {
  final store = await _store(readAnswers: readAnswers);
  final stt = FakeRecognizer();
  final tts = FakeOutput()..instant = instantSpeech;
  final voice = VoiceController(
    recognizer: stt,
    output: tts,
    intercom: IntercomAudio(supported: false),
    ensureMicrophonePermission: () async {},
    finalWait: const Duration(milliseconds: 5),
  );
  final bus = VoiceTriggerBus();
  final client = ChatClient(httpClient: MockClient((request) async {
    asked?.add((jsonDecode(request.body) as Map)['message'] as String);
    return reply();
  }));
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: AssistantScreen(
        settingsStore: store, client: client, voice: voice, voiceBus: bus),
  ));
  await tester.pump();
  return _Rig(tester, store, client, stt, tts, voice, bus);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
}

final _micTooltip = find.byTooltip('Ask by voice');

void main() {
  testWidgets(
      'mic flow: tap listens with a ring and live transcript, final transcript is sent and the answer spoken',
      (tester) async {
    final asked = <String>[];
    final rig = await _pump(tester,
        reply: () => _answer('Your last ride was 12.4 km.'), asked: asked);
    expect(_micTooltip, findsOneWidget);

    await tester.tap(_micTooltip);
    await _settle(tester);
    expect(rig.voice.state, VoiceState.listening);
    expect(find.byKey(const ValueKey('mic-ring')), findsOneWidget);
    expect(find.byTooltip('Stop listening'), findsOneWidget);

    rig.stt.partial('my last ride');
    await tester.pump();
    expect(find.widgetWithText(TextField, 'my last ride'), findsOneWidget);

    rig.stt.finalResult('how was my last ride');
    await _settle(tester);
    expect(asked, ['how was my last ride']);
    expect(find.text('Your last ride was 12.4 km.'), findsOneWidget);
    expect(find.byKey(const ValueKey('mic-ring')), findsNothing);
    // Only the answer text is spoken, never the tool card.
    expect(rig.tts.spoken, ['Your last ride was 12.4 km.']);
  });

  testWidgets('answers are not read when the setting is off', (tester) async {
    final rig =
        await _pump(tester, reply: () => _answer('Cevap'), readAnswers: false);
    await tester.enterText(find.byType(TextField), 'merhaba');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await _settle(tester);
    expect(find.text('Cevap'), findsOneWidget);
    expect(rig.tts.spoken, isEmpty);
  });

  testWidgets(
      'advise_stop in the tool result adds the fixed stop sentence after the answer',
      (tester) async {
    final rig = await _pump(tester,
        reply: () =>
            _answer('A fault was recorded.', result: {'advise_stop': true}));
    await tester.enterText(find.byType(TextField), 'any faults');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await _settle(tester);
    expect(rig.tts.spoken,
        ['A fault was recorded.', CriticalAnnouncer.adviseStopSentence]);
  });

  testWidgets('without advise_stop nothing is added to the answer',
      (tester) async {
    final plain = await _pump(tester,
        reply: () =>
            _answer('Everything is fine.', result: {'advise_stop': false}));
    await tester.enterText(find.byType(TextField), 'durum');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await _settle(tester);
    expect(plain.tts.spoken, ['Everything is fine.']);
  });

  testWidgets('sending a new question stops the answer that is being spoken',
      (tester) async {
    final rig = await _pump(tester,
        reply: () => _answer('Uzun bir cevap'), instantSpeech: false);
    await tester.enterText(find.byType(TextField), 'bir');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await _settle(tester);
    expect(rig.tts.speaking, isTrue);
    expect(rig.voice.state, VoiceState.speaking);

    await tester.enterText(find.byType(TextField), 'iki');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await _settle(tester);
    expect(rig.tts.stopCalls, greaterThan(0));
    // The second answer is being spoken; the first one was cut off.
    expect(rig.tts.spoken, ['Uzun bir cevap', 'Uzun bir cevap']);
    rig.tts.finish();
    await _settle(tester);
  });

  testWidgets('tapping the mic while speaking stops the speech and listens',
      (tester) async {
    final rig = await _pump(tester,
        reply: () => _answer('Cevap'), instantSpeech: false);
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await _settle(tester);
    expect(rig.voice.state, VoiceState.speaking);
    await tester.tap(find.byTooltip('Stop reading and speak'));
    await _settle(tester);
    expect(rig.tts.stopCalls, greaterThan(0));
    expect(rig.voice.state, VoiceState.listening);
  });

  testWidgets('a failed recognition shows a friendly message',
      (tester) async {
    final rig = await _pump(tester, reply: () => _answer('x'));
    rig.stt.initializeResult = false;
    await tester.tap(_micTooltip);
    await _settle(tester);
    expect(find.textContaining('Microphone permission was not granted'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.textContaining('Microphone permission was not granted'), findsNothing);
  });

  testWidgets(
      'push-to-talk: long hold sends, empty long hold does nothing, tap repeats',
      (tester) async {
    final asked = <String>[];
    final rig = await _pump(tester,
        reply: () => _answer('Cevap bir'), readAnswers: false, asked: asked);
    await tester.enterText(find.byType(TextField), 'first');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await _settle(tester);
    expect(rig.tts.spoken, isEmpty); // setting off

    // Long hold with speech: send on release.
    rig.bus.emit(VoiceTrigger.startListening);
    await _settle(tester);
    expect(rig.voice.state, VoiceState.listening);
    rig.stt.partial('second question');
    rig.bus.emit(VoiceTrigger.stopAndSend);
    await _settle(tester);
    expect(asked, ['first', 'second question']);

    // Empty long hold: nothing is sent, nothing is spoken, no error.
    rig.bus.emit(VoiceTrigger.startListening);
    await _settle(tester);
    rig.bus.emit(VoiceTrigger.stopAndSend);
    await _settle(tester);
    expect(asked, hasLength(2));
    expect(rig.tts.spoken, isEmpty);
    expect(rig.voice.error, isNull);
    expect(rig.voice.state, VoiceState.idle);

    // Tap that heard nothing: repeat the last answer although reading is off.
    rig.bus.emit(VoiceTrigger.startListening);
    await _settle(tester);
    rig.bus.emit(VoiceTrigger.stopAfterTap);
    await _settle(tester);
    expect(asked, hasLength(2));
    expect(rig.tts.spoken, ['Cevap bir']);

    // A tap that did hear something sends it and does not repeat.
    rig.tts.spoken.clear();
    rig.bus.emit(VoiceTrigger.startListening);
    await _settle(tester);
    rig.stt.partial('third');
    rig.bus.emit(VoiceTrigger.stopAfterTap);
    await _settle(tester);
    expect(asked, ['first', 'second question', 'third']);
    expect(rig.tts.spoken, isEmpty);
  });

  testWidgets('a tap with nothing to repeat does nothing', (tester) async {
    final rig = await _pump(tester, reply: () => _answer('x'));
    rig.bus.emit(VoiceTrigger.startListening);
    await _settle(tester);
    rig.bus.emit(VoiceTrigger.stopAfterTap);
    await _settle(tester);
    expect(rig.tts.spoken, isEmpty);
    expect(rig.voice.error, isNull);
  });

  testWidgets('a press while speaking stops the speech and listens',
      (tester) async {
    final rig = await _pump(tester,
        reply: () => _answer('Cevap'), instantSpeech: false);
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await _settle(tester);
    expect(rig.voice.state, VoiceState.speaking);
    rig.bus.emit(VoiceTrigger.startListening);
    await _settle(tester);
    expect(rig.tts.stopCalls, greaterThan(0));
    expect(rig.voice.state, VoiceState.listening);
  });

  testWidgets(
      'a trigger that arrived before the screen existed starts listening once it is built',
      (tester) async {
    final stt = FakeRecognizer();
    final voice = VoiceController(
        recognizer: stt,
        output: FakeOutput(),
        intercom: IntercomAudio(supported: false),
        ensureMicrophonePermission: () async {},
        finalWait: const Duration(milliseconds: 5));
    final bus = VoiceTriggerBus()..emit(VoiceTrigger.startListening);
    final store = await _store();
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: AssistantScreen(settingsStore: store, voice: voice, voiceBus: bus),
    ));
    await _settle(tester);
    expect(voice.state, VoiceState.listening);
    expect(stt.listenCalls, 1);
  });

  testWidgets('the route chip shows the intercom state on Android',
      (tester) async {
    final store = await _store();
    final intercom = FakeIntercom();
    final voice = VoiceController(
        recognizer: FakeRecognizer(),
        output: FakeOutput(),
        intercom: intercom.audio,
        ensureMicrophonePermission: () async {},
        ensureBluetoothPermission: () async {});
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: AssistantScreen(
          settingsStore: store, voice: voice, voiceBus: VoiceTriggerBus()),
    ));
    await _settle(tester);
    expect(find.text('Intercom connected'), findsOneWidget);
    intercom.headset = false;
    await voice.refreshIntercom();
    await tester.pump();
    expect(find.text('Phone microphone'), findsOneWidget);
  });

  group('VOICE_COMMAND entry', () {
    test('a running app brought forward by the intent starts listening',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final intercom = FakeIntercom();
      final bus = VoiceTriggerBus();
      final got = <VoiceTrigger>[];
      bus.attach(got.add);
      await bindVoiceCommandIntent(intercom.audio, bus);
      expect(got, isEmpty);
      await intercom.nativeVoiceCommand();
      expect(got, [VoiceTrigger.startListening]);
    });

    test('a cold start by the intent is read once from the native side',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final intercom = FakeIntercom()..pendingVoiceCommand = true;
      final bus = VoiceTriggerBus();
      final got = <VoiceTrigger>[];
      bus.attach(got.add);
      await bindVoiceCommandIntent(intercom.audio, bus);
      expect(got, [VoiceTrigger.startListening]);
      await bindVoiceCommandIntent(intercom.audio, bus);
      expect(got, hasLength(1)); // consumed
    });

    test('no intent and no native side: nothing is triggered', () async {
      final bus = VoiceTriggerBus();
      final got = <VoiceTrigger>[];
      bus.attach(got.add);
      await bindVoiceCommandIntent(IntercomAudio(supported: false), bus);
      expect(got, isEmpty);
    });

    testWidgets('the shell opens the assistant and the screen starts listening',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final intercom = FakeIntercom();
      final bus = VoiceTriggerBus();
      final stt = FakeRecognizer();
      final voice = VoiceController(
          recognizer: stt,
          output: FakeOutput(),
          intercom: IntercomAudio(supported: false),
          ensureMicrophonePermission: () async {},
          finalWait: const Duration(milliseconds: 5));
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: AppShell(voiceBus: bus, intercom: intercom.audio, voice: voice),
      ));
      await tester.pump();
      await tester.tap(find.descendant(
          of: find.byType(NavigationRail), matching: find.text('Settings')));
      await tester.pumpAndSettle();
      expect(
          find.text('Hello, I am the Ride Assistant. What would you like to know?'), findsNothing);

      await intercom.nativeVoiceCommand();
      await _settle(tester);
      expect(find.text('Hello, I am the Ride Assistant. What would you like to know?'),
          findsOneWidget);
      expect(voice.state, VoiceState.listening);
      expect(stt.listenCalls, 1);
    });
  });
}
