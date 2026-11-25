import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart' show MaxLengthEnforcement;

import 'package:vehicle_mobile/models/chat_message.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/assistant_provider_client.dart';
import 'package:vehicle_mobile/services/chat_client.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/services/voice/critical_announcer.dart';
import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/services/voice/voice_triggers.dart';
import 'package:vehicle_mobile/ui/assistant/chat_widgets.dart';
import 'package:vehicle_mobile/ui/assistant/model_chip.dart';
import 'package:vehicle_mobile/ui/assistant/voice_widgets.dart';
import 'package:vehicle_mobile/ui/shell/shell_scope.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';

/// Example questions of the empty state (the rider talks Turkish to the bike).
const List<String> assistantExampleQuestions = [
  'Son sürüşüm nasıldı?',
  'Son sürüşün özeti',
  'Kayıtlı arızalar var mı?',
];

/// A question handed to the assistant from outside (a notification's "ask"
/// button): shown in the input, not sent. [seq] tells a repeat from a new one.
class AssistantPrefill {
  const AssistantPrefill(this.seq, this.question, this.sessionId);

  final int seq;
  final String question;
  final String? sessionId;
}

/// Rider assistant "Sürüş Asistanı" (D-121): a text chat against `POST /chat` of the active
/// host. The server picks one read-only vehicle-mcp tool and phrases its
/// result; this screen only shows the answer and the tool that computed the
/// numbers. It never computes or rephrases a number and adds no advice. The
/// conversation lives in memory only: answers may contain ride data.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    this.settingsStore = const AppSettingsStore(),
    this.client,
    this.providerClient,
    this.sessionId,
    this.voice,
    this.voiceBus,
    this.prefill,
  });

  final AppSettingsStore settingsStore;
  final ChatClient? client;

  /// Client of the header model chip (D-127); tests inject a fake.
  final AssistantProviderClient? providerClient;

  /// Voice front end (microphone, reading answers aloud, intercom routing);
  /// tests inject one with fake STT/TTS. Created and owned here when null.
  final VoiceController? voice;

  /// Where handlebar push-to-talk and the voice-command button arrive;
  /// defaults to [VoiceTriggerBus.instance].
  final VoiceTriggerBus? voiceBus;

  /// Prefilled question from a notification (D-123).
  final ValueListenable<AssistantPrefill?>? prefill;

  /// Ride the question is about (opened from a ride screen), sent as `session_id`.
  final String? sessionId;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen>
    with SingleTickerProviderStateMixin {
  late final ChatClient _client;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _sessionId;
  bool _sending = false;

  /// Pulse of the placeholder card while waiting (no typing dots).
  late final AnimationController _pulse;

  late final VoiceController _voice;
  late final bool _ownsVoice;
  late final VoiceTriggerBus _bus;
  late final CriticalAnnouncer _announcer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _client = widget.client ?? ChatClient();
    _sessionId = widget.sessionId;
    _ownsVoice = widget.voice == null;
    _voice = widget.voice ?? VoiceController();
    _voice.onTranscript = _onTranscript;
    _voice.onEmptyTap = _repeatLast;
    _voice.addListener(_onVoiceChanged);
    _announcer = CriticalAnnouncer(speak: _voice.speak);
    _bus = widget.voiceBus ?? VoiceTriggerBus.instance;
    // Triggers that arrived before this screen existed are delivered after
    // the first frame (starting to listen sets state).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bus.attach(_onTrigger);
    });
    _voice.refreshIntercom();
    widget.prefill?.addListener(_onPrefill);
    _onPrefill();
  }

  int _prefillSeen = 0;

  void _onPrefill() {
    final prefill = widget.prefill?.value;
    if (prefill == null || prefill.seq == _prefillSeen) return;
    _prefillSeen = prefill.seq;
    _controller.value = TextEditingValue(
      text: prefill.question,
      selection: TextSelection.collapsed(offset: prefill.question.length),
    );
    if (prefill.sessionId != null) _sessionId = prefill.sessionId;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.prefill?.removeListener(_onPrefill);
    _bus.detach(_onTrigger);
    _voice.removeListener(_onVoiceChanged);
    _voice.onTranscript = null;
    _voice.onEmptyTap = null;
    if (_ownsVoice) {
      _voice.dispose();
    } else {
      _voice.cancelListening();
      _voice.stopSpeaking();
    }
    _pulse.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Language of the UI, sent as the `/chat` locale (D-130 item 5).
  String _localeCode = 'en';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localeCode = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    // A new question silences the previous answer (and any listening).
    await _voice.cancelListening();
    await _voice.stopSpeaking();
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage.user(text));
      _sending = true;
    });
    _pulse.repeat(reverse: true);
    _scrollToEnd();

    ChatMessage reply;
    try {
      reply = await _ask(text);
    } catch (_) {
      reply = const ChatMessage.failure('Could not read the host settings.');
    }
    _pulse.stop();
    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _sending = false;
    });
    _scrollToEnd();
    if (!reply.isFailure) unawaited(_speakReply(reply));
  }

  /// Reads the answer text only (never the tool card), then the fixed stop
  /// sentence when the tool result advises it (D-085 item 4): offline, not
  /// phrased by the LLM, informational only.
  Future<void> _speakReply(ChatMessage reply) async {
    final spoken = await _voice.speak(reply.text);
    if (spoken && CriticalAnnouncer.resultAdvisesStop(reply.result)) {
      await _announcer.announce(const AdviseStopEvent());
    }
  }

  void _onTranscript(String text) {
    _controller.text = text;
    _send(text);
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    if (_voice.isListening || _voice.state == VoiceState.preparing) {
      final partial = _voice.partial;
      if (partial.isNotEmpty && _controller.text != partial) {
        _controller.value = TextEditingValue(
          text: partial,
          selection: TextSelection.collapsed(offset: partial.length),
        );
      }
    }
    setState(() {});
  }

  void _onTrigger(VoiceTrigger trigger) {
    switch (trigger) {
      case VoiceTrigger.startListening:
        if (!_sending) _voice.startListening();
      case VoiceTrigger.stopAndSend:
        _voice.stopListening(onEmpty: EmptyTranscript.nothing);
      case VoiceTrigger.stopAfterTap:
        _voice.stopListening(onEmpty: EmptyTranscript.repeat);
    }
  }

  /// A tap of the handlebar button heard nothing: read the last answer again.
  Future<void> _repeatLast() async {
    for (final message in _messages.reversed) {
      if (message.role == ChatRole.assistant && !message.isFailure) {
        await _voice.speak(message.text, force: true);
        return;
      }
    }
  }

  Future<ChatMessage> _ask(String text) async {
    var settings = await widget.settingsStore.load();
    if (!settings.isServerConfigured || (settings.apiToken ?? '').isEmpty) {
      return const ChatMessage.failure(
          'No host with a device token is configured. Add one in Settings > Hosts.');
    }
    var result = await _send1(settings, text);
    if (result.outcome == ChatOutcome.unreachable) {
      // The cached host may have gone away (left home Wi-Fi): probe the list
      // again and retry once on another host.
      HostResolver.invalidate();
      final fresh = await widget.settingsStore.load(reprobe: true);
      if (fresh.isServerConfigured && fresh.hostId != settings.hostId) {
        settings = fresh;
        result = await _send1(settings, text);
      }
    }
    return _describe(result, settings);
  }

  Future<ChatResult> _send1(AppSettings settings, String text) => _client.send(
        baseUrl: settings.serverBaseUrl!,
        apiToken: settings.apiToken!,
        message: text,
        sessionId: _sessionId,
        locale: _localeCode,
      );

  ChatMessage _describe(ChatResult result, AppSettings settings) {
    final host = settings.hostName ?? 'the host';
    switch (result.outcome) {
      case ChatOutcome.ok:
        return ChatMessage.fromAnswer(result.answer!);
      case ChatOutcome.unauthorized:
        return ChatMessage.failure(
            'The device token was rejected by "$host". Check the token in Settings > Hosts.');
      case ChatOutcome.invalid:
        return ChatMessage.failure(
            'The server rejected the message: ${result.message}');
      case ChatOutcome.rateLimited:
        final wait = result.retryAfterSeconds;
        return ChatMessage.failure(wait == null
            ? 'Rate limited. Try again shortly.'
            : 'Rate limited. Try again in $wait s.');
      case ChatOutcome.disabled:
        return ChatMessage.failure('The assistant is disabled on "$host".');
      case ChatOutcome.unreachable:
        return ChatMessage.failure('Host unreachable: "$host".');
      case ChatOutcome.failed:
        return ChatMessage.failure(
            'Request failed: ${result.message ?? 'unknown error'}');
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AssistantAvatar(size: 28),
            const SizedBox(width: Spacing.sm),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sürüş Asistanı', overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  ActiveModelChip(
                      settingsStore: widget.settingsStore,
                      client: widget.providerClient),
                ],
              ),
            ),
          ],
        ),
        actions: [
          const HeaderActions(),
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear conversation',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _sending ? null : () => setState(_messages.clear),
            ),
        ],
      ),
      body: SafeArea(
        // One centred column: full width on a phone, at most 720 px on a wide window.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ContentWidth.assistant),
            child: Column(
              children: [
                if (_sessionId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.lg, Spacing.sm, Spacing.lg, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        avatar: const Icon(Icons.route, size: 18),
                        label: Text('Ride $_sessionId'),
                        onDeleted: () => setState(() => _sessionId = null),
                      ),
                    ),
                  ),
                Expanded(
                    child: _messages.isEmpty
                        ? _emptyState(context)
                        : _messageList()),
                if (_sending) const LinearProgressIndicator(minHeight: 2),
                if (_voice.error != null) _voiceError(context),
                if (_voice.routeLabel != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.lg, Spacing.xs, Spacing.lg, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: VoiceRouteChip(
                        label: _voice.routeLabel!,
                        connected: _voice.routeLabel == intercomConnectedLabel,
                      ),
                    ),
                  ),
                AssistantComposer(
                  controller: _controller,
                  sending: _sending,
                  onSend: _send,
                  hintText:
                      _voice.isListening ? 'Dinliyorum...' : 'Bir soru yaz',
                  micButton: MicButton(
                    state: _voice.state,
                    onPressed: _sending ? null : _voice.toggleMic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _voiceError(BuildContext context) {
    final t = context.vehicle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.lg, 0),
      child: Material(
        color: t.error.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: t.error.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.md, Spacing.xs, Spacing.xs, Spacing.xs),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: t.error),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(_voice.error!,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              IconButton(
                tooltip: 'Kapat',
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(fixedSize: const Size(48, 48)),
                onPressed: _voice.clearError,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageList() => ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
        itemCount: _messages.length + (_sending ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _messages.length) return PendingAnswerCard(pulse: _pulse);
          return ChatBubble(message: _messages[i]);
        },
      );

  Widget _emptyState(BuildContext context) => EmptyState(
        icon: Icons.two_wheeler,
        message: 'Merhaba, ben Sürüş Asistanı. Ne öğrenmek istersin?',
        chips: assistantExampleQuestions,
        onChip: _send,
      );
}

/// Placeholder card with a soft pulse while the host answers.
class PendingAnswerCard extends StatelessWidget {
  const PendingAnswerCard({super.key, required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    Widget bar(double factor) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: factor,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
                color: t.surfaceRaised, borderRadius: BorderRadius.circular(6)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 2),
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.outline),
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1).animate(pulse),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AssistantAvatar(size: 24),
                const SizedBox(height: Spacing.md),
                bar(0.9),
                const SizedBox(height: Spacing.sm),
                bar(0.6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded input bar pinned at the bottom with a large circular send button.
/// [micButton] is the voice button slot (hold or tap to talk).
class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
    this.micButton,
    this.hintText = 'Bir soru yaz',
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onSend;

  /// The microphone button (see `MicButton`); omitted when voice is unavailable.
  final Widget? micButton;

  final String hintText;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.sm, Spacing.lg, Spacing.md),
      child: Material(
        color: t.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: t.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.xs, Spacing.xs, Spacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: chatMaxMessageLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  textInputAction: TextInputAction.send,
                  onSubmitted: onSend,
                  decoration: InputDecoration(
                    hintText: hintText,
                    counterText: '',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              if (micButton != null) micButton!,
              const SizedBox(width: Spacing.xs),
              IconButton.filled(
                tooltip: 'Send',
                iconSize: 26,
                style: IconButton.styleFrom(
                  fixedSize: const Size(56, 56),
                  shape: const CircleBorder(),
                  backgroundColor: t.accent,
                  foregroundColor: t.onAccent,
                ),
                icon: const Icon(Icons.arrow_upward),
                onPressed: sending ? null : () => onSend(controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
