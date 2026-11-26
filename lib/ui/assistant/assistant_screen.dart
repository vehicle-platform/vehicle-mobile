import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart' show MaxLengthEnforcement;

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/chat_message.dart';
import 'package:vehicle_mobile/models/conversation.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/assistant_provider_client.dart';
import 'package:vehicle_mobile/services/chat_client.dart';
import 'package:vehicle_mobile/services/conversations_client.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/services/voice/critical_announcer.dart';
import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/services/voice/voice_ports.dart';
import 'package:vehicle_mobile/services/voice/voice_triggers.dart';
import 'package:vehicle_mobile/ui/assistant/chat_widgets.dart';
import 'package:vehicle_mobile/ui/assistant/conversation_list.dart';
import 'package:vehicle_mobile/ui/assistant/model_chip.dart';
import 'package:vehicle_mobile/ui/assistant/voice_widgets.dart';
import 'package:vehicle_mobile/ui/shell/shell_scope.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';

/// Example questions of the empty state, in the language of the UI.
List<String> assistantExampleQuestions(AppLocalizations l) =>
    [l.assistantExample1, l.assistantExample2, l.assistantExample3];

/// A question handed to the assistant from outside (a notification's "ask"
/// button): shown in the input, not sent. [seq] tells a repeat from a new one.
class AssistantPrefill {
  const AssistantPrefill(this.seq, this.question, this.sessionId);

  final int seq;
  final String question;
  final String? sessionId;
}

/// Rider assistant (D-121, D-128): a logbook-style transcript against
/// `POST /chat` of the active host, with server-stored conversations,
/// search, temporary-chat mode and follow-up chips.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    this.settingsStore = const AppSettingsStore(),
    this.client,
    this.providerClient,
    this.conversationsClient,
    this.sessionId,
    this.voice,
    this.voiceBus,
    this.prefill,
  });

  final AppSettingsStore settingsStore;
  final ChatClient? client;

  /// Client of the header model chip (D-127); tests inject a fake.
  final AssistantProviderClient? providerClient;

  /// Client of `/conversations*` (D-128); tests inject a fake.
  final ConversationsClient? conversationsClient;

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

class _AssistantScreenState extends State<AssistantScreen> {
  late final ChatClient _client;
  late final ConversationsClient _conversationsClient;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _sessionId;
  String? _conversationId;
  bool _temporary = false;
  bool _sending = false;

  List<ConversationSummary> _conversations = const [];
  bool _conversationsLoading = false;
  bool _conversationsAvailable = false;
  List<ConversationSearchHit>? _searchHits;
  bool _searching = false;

  late final VoiceController _voice;
  late final bool _ownsVoice;
  late final VoiceTriggerBus _bus;
  late final CriticalAnnouncer _announcer;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ChatClient();
    _conversationsClient = widget.conversationsClient ?? ConversationsClient();
    _sessionId = widget.sessionId;
    _ownsVoice = widget.voice == null;
    _voice = widget.voice ?? VoiceController();
    _voice.onTranscript = _onTranscript;
    _voice.onEmptyTap = _repeatLast;
    _voice.addListener(_onVoiceChanged);
    _announcer = CriticalAnnouncer(
        speak: _voice.speak, sentences: () => AnnouncerSentences.fromL10n(_l));
    _bus = widget.voiceBus ?? VoiceTriggerBus.instance;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bus.attach(_onTrigger);
    });
    _voice.refreshIntercom();
    widget.prefill?.addListener(_onPrefill);
    _onPrefill();
    unawaited(_loadConversations());
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
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Language of the UI, sent as the `/chat` locale (D-130 item 5), and its
  /// strings for the failure texts built after an await.
  String _localeCode = 'en';
  late AppLocalizations _l = lookupAppLocalizations(const Locale('en'));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localeCode = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    _l = context.l10n;
    _voice.localeTag = voiceTagFor(_localeCode);
  }

  Future<(String, String)?> _target() async {
    try {
      final s = await widget.settingsStore.load();
      final token = s.apiToken ?? '';
      if (!s.isServerConfigured || token.isEmpty) return null;
      return (s.serverBaseUrl!, token);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadConversations() async {
    final target = await _target();
    if (target == null || !mounted) return;
    setState(() => _conversationsLoading = true);
    final res = await _conversationsClient.list(
        baseUrl: target.$1, token: target.$2);
    if (!mounted) return;
    if (res.isSuccess && res.value != null) {
      setState(() {
        _conversations = res.value!.conversations;
        _conversationsAvailable = true;
        _conversationsLoading = false;
      });
    } else {
      setState(() {
        _conversationsLoading = false;
        if (res.outcome == ConvOutcome.forbidden ||
            res.outcome == ConvOutcome.notFound ||
            res.outcome == ConvOutcome.notSupported) {
          _conversationsAvailable = false;
        }
      });
    }
  }

  Future<void> _selectConversation(String id, {bool closeSheet = false}) async {
    if (closeSheet && mounted) Navigator.of(context).pop();
    final target = await _target();
    if (target == null || !mounted) return;
    final res = await _conversationsClient.get(
        baseUrl: target.$1, token: target.$2, id: id);
    if (!mounted) return;
    if (res.isSuccess && res.value != null) {
      setState(() {
        _conversationId = res.value!.conversation.id;
        _temporary = false;
        _searchHits = null;
        _messages
          ..clear()
          ..addAll(res.value!.messages);
      });
      _scrollToEnd();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l.assistantLoadChatFailed)),
      );
    }
  }

  void _startNewChat({bool closeSheet = false}) {
    if (closeSheet && mounted) Navigator.of(context).pop();
    setState(() {
      _conversationId = null;
      _messages.clear();
      _searchHits = null;
    });
  }

  void _toggleTemporary() {
    setState(() {
      _temporary = !_temporary;
      if (_temporary) {
        _conversationId = null;
        _messages.clear();
      }
    });
  }

  Future<void> _renameConversation(
      ConversationSummary conv, String newTitle) async {
    final target = await _target();
    if (target == null || !mounted) return;
    final res = await _conversationsClient.rename(
      baseUrl: target.$1,
      token: target.$2,
      id: conv.id,
      title: newTitle,
    );
    if (!mounted || !res.isSuccess || res.value == null) return;
    setState(() {
      _conversations = [
        for (final item in _conversations)
          item.id == conv.id ? res.value! : item,
      ];
    });
  }

  Future<void> _deleteConversation(ConversationSummary conv) async {
    final target = await _target();
    if (target == null || !mounted) return;
    final res = await _conversationsClient.deleteOne(
      baseUrl: target.$1,
      token: target.$2,
      id: conv.id,
    );
    if (!mounted || !res.isSuccess) return;
    setState(() {
      _conversations =
          _conversations.where((c) => c.id != conv.id).toList(growable: false);
      if (_conversationId == conv.id) {
        _conversationId = null;
        _messages.clear();
      }
    });
  }

  Future<void> _searchConversations(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _searchHits = null;
        _searching = false;
      });
      return;
    }
    final target = await _target();
    if (target == null || !mounted) return;
    setState(() => _searching = true);
    final res = await _conversationsClient.search(
      baseUrl: target.$1,
      token: target.$2,
      query: q,
    );
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searchHits = res.isSuccess ? (res.value ?? const []) : const [];
    });
  }

  Future<void> _openConversationsSheet() async {
    unawaited(_loadConversations());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.75,
          child: ConversationListPane(
            conversations: _conversations,
            activeId: _conversationId,
            loading: _conversationsLoading,
            searchHits: _searchHits,
            searching: _searching,
            onSelect: (id) => _selectConversation(id, closeSheet: true),
            onNewChat: () => _startNewChat(closeSheet: true),
            onRename: (c, t) async {
              await _renameConversation(c, t);
              if (ctx.mounted) setSheetState(() {});
            },
            onDelete: (c) async {
              await _deleteConversation(c);
              if (ctx.mounted) setSheetState(() {});
            },
            onSearch: (q) async {
              await _searchConversations(q);
              if (ctx.mounted) setSheetState(() {});
            },
          ),
        ),
      ),
    );
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    await _voice.cancelListening();
    await _voice.stopSpeaking();
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage.user(text));
      _sending = true;
    });
    _scrollToEnd();

    ChatMessage reply;
    String? returnedConvId;
    try {
      final result = await _ask(text);
      reply = result.$1;
      returnedConvId = result.$2;
    } catch (_) {
      reply = ChatMessage.failure(_l.assistantFailSettings);
    }
    if (!mounted) return;
    final createdNew =
        !_temporary && returnedConvId != null && _conversationId == null;
    setState(() {
      _messages.add(reply);
      _sending = false;
      if (!_temporary && returnedConvId != null) {
        _conversationId = returnedConvId;
      }
    });
    _scrollToEnd();
    if (createdNew) unawaited(_loadConversations());
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

  Future<(ChatMessage, String?)> _ask(String text) async {
    var settings = await widget.settingsStore.load();
    if (!settings.isServerConfigured || (settings.apiToken ?? '').isEmpty) {
      return (ChatMessage.failure(_l.assistantFailNoHost), null);
    }
    var result = await _send1(settings, text);
    if (result.outcome == ChatOutcome.unreachable) {
      HostResolver.invalidate();
      final fresh = await widget.settingsStore.load(reprobe: true);
      if (fresh.isServerConfigured && fresh.hostId != settings.hostId) {
        settings = fresh;
        result = await _send1(settings, text);
      }
    }
    return (_describe(result, settings), result.answer?.conversationId);
  }

  Future<ChatResult> _send1(AppSettings settings, String text) => _client.send(
        baseUrl: settings.serverBaseUrl!,
        apiToken: settings.apiToken!,
        message: text,
        sessionId: _sessionId,
        locale: _localeCode,
        conversationId: _temporary ? null : _conversationId,
        temporary: _temporary,
      );

  ChatMessage _describe(ChatResult result, AppSettings settings) {
    final host = settings.hostName ?? _l.assistantTheHost;
    switch (result.outcome) {
      case ChatOutcome.ok:
        return ChatMessage.fromAnswer(result.answer!);
      case ChatOutcome.unauthorized:
        return ChatMessage.failure(_l.assistantFailUnauthorized(host));
      case ChatOutcome.invalid:
        return ChatMessage.failure(
            _l.assistantFailInvalid(result.message ?? ''));
      case ChatOutcome.rateLimited:
        final wait = result.retryAfterSeconds;
        return ChatMessage.failure(wait == null
            ? _l.assistantFailRateLimited
            : _l.assistantFailRateLimitedIn(wait));
      case ChatOutcome.disabled:
        return ChatMessage.failure(_l.assistantFailDisabled(host));
      case ChatOutcome.unreachable:
        return ChatMessage.failure(_l.assistantFailUnreachable(host));
      case ChatOutcome.failed:
        return ChatMessage.failure(
            _l.assistantFailFailed(result.message ?? _l.assistantFailUnknown));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.standard,
        curve: Motion.curve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.vehicle;
    final phone = Breakpoints.isCompact(MediaQuery.sizeOf(context).width);
    final voiceRoute = _voice.route;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidebar =
            _conversationsAvailable && constraints.maxWidth >= Breakpoints.wide;
        final chatBody = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ContentWidth.assistant),
            child: Column(
              children: [
                if (_temporary)
                  Container(
                    key: const ValueKey('temporary-chat-banner'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.lg, vertical: Spacing.sm),
                    decoration: BoxDecoration(
                      color: t.surfaceRaised,
                      border: Border(
                        left: BorderSide(color: t.accent, width: 3),
                        bottom: BorderSide(color: t.hairline),
                      ),
                    ),
                    child: Text(
                      l.assistantTemporaryOn,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(color: t.textSecondary),
                    ),
                  ),
                if (_sessionId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.lg, Spacing.sm, Spacing.lg, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        avatar: const Icon(Icons.route, size: 18),
                        label: Text(l.assistantRideChip(_sessionId!)),
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
                if (voiceRoute != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.lg, Spacing.xs, Spacing.lg, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: VoiceRouteChip(route: voiceRoute),
                    ),
                  ),
                AssistantComposer(
                  controller: _controller,
                  sending: _sending,
                  onSend: _send,
                  hintText: _voice.isListening
                      ? l.assistantHintListening
                      : l.assistantHint,
                  micButton: phone
                      ? null
                      : MicButton(
                          state: _voice.state,
                          onPressed: _sending ? null : _voice.toggleMic,
                        ),
                  holdToTalk: !phone
                      ? null
                      : HoldToTalkButton(
                          state: _voice.state,
                          onStart: _sending ? () {} : _voice.startListening,
                          onRelease: () => _voice.stopListening(),
                          onTap: _sending ? () {} : _voice.toggleMic,
                        ),
                ),
              ],
            ),
          ),
        );

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.assistantName, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                ActiveModelChip(
                    settingsStore: widget.settingsStore,
                    client: widget.providerClient),
              ],
            ),
            actions: [
              if (_conversationsAvailable && !showSidebar)
                IconButton(
                  key: const ValueKey('open-conversations-button'),
                  tooltip: l.assistantChatsTitle,
                  icon: const Icon(Icons.history),
                  onPressed: _openConversationsSheet,
                ),
              IconButton(
                key: const ValueKey('temporary-chat-toggle'),
                tooltip: _temporary
                    ? l.assistantTemporaryOff
                    : l.assistantTemporaryChat,
                icon: Icon(
                  _temporary ? Icons.visibility_off : Icons.visibility_off_outlined,
                  color: _temporary ? t.accent : null,
                ),
                onPressed: _sending ? null : _toggleTemporary,
              ),
              const HeaderActions(),
              if (_messages.isNotEmpty)
                IconButton(
                  tooltip: l.assistantClear,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: _sending ? null : () => _startNewChat(),
                ),
            ],
          ),
          body: SafeArea(
            child: showSidebar
                ? Row(
                    children: [
                      SizedBox(
                        width: 280,
                        child: ConversationListPane(
                          conversations: _conversations,
                          activeId: _conversationId,
                          loading: _conversationsLoading,
                          searchHits: _searchHits,
                          searching: _searching,
                          onSelect: _selectConversation,
                          onNewChat: _startNewChat,
                          onRename: _renameConversation,
                          onDelete: _deleteConversation,
                          onSearch: _searchConversations,
                        ),
                      ),
                      VerticalDivider(width: 1, thickness: 1, color: t.hairline),
                      Expanded(child: chatBody),
                    ],
                  )
                : chatBody,
          ),
        );
      },
    );
  }

  String _voiceErrorText(AppLocalizations l, VoiceError error) =>
      switch (error) {
        VoiceError.initTimeout => l.assistantVoiceInitTimeout,
        VoiceError.noSpeech => l.assistantVoiceNoSpeech,
        VoiceError.unavailable => l.assistantVoiceUnavailable,
        VoiceError.permission => l.assistantVoicePermission,
        VoiceError.language => l.assistantVoiceLanguage,
        VoiceError.network => l.assistantVoiceNetwork,
      };

  Widget _voiceError(BuildContext context) {
    final t = context.vehicle;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.lg, 0),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(left: BorderSide(color: t.critical, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(
            Spacing.md, Spacing.xs, Spacing.xs, Spacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(_voiceErrorText(l, _voice.error!),
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            IconButton(
              tooltip: l.assistantClose,
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(fixedSize: const Size(48, 48)),
              onPressed: _voice.clearError,
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageList() {
    final l = context.l10n;
    final last = _messages.last;
    final showChips = !_sending &&
        last.role == ChatRole.assistant &&
        !last.isFailure &&
        last.chips.isNotEmpty;
    final step = _sessionId == null
        ? l.assistantStepReading
        : l.assistantStepReadingRide(_sessionId!);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
      itemCount: _messages.length + (_sending ? 1 : 0) + (showChips ? 1 : 0),
      itemBuilder: (_, i) {
        if (i < _messages.length) return TranscriptEntry(message: _messages[i]);
        if (_sending) return AssistantStepLine(text: step);
        return FollowUpChips(chips: last.chips, onTap: _send);
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    final l = context.l10n;
    final t = context.vehicle;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(upperFor(context, l.assistantName),
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: Spacing.sm),
          Text(l.assistantGreeting,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(color: t.textPrimary)),
          const SizedBox(height: Spacing.lg),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final q in assistantExampleQuestions(l))
                ActionChip(label: Text(q), onPressed: () => _send(q)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Input bar pinned at the bottom: a hairline-framed field with a 56 px send
/// button. [micButton] is the voice button slot of wide layouts; [holdToTalk]
/// is the large full-width control under the field on a phone.
class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.hintText,
    this.micButton,
    this.holdToTalk,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onSend;

  /// The microphone button (see `MicButton`); omitted when voice is unavailable.
  final Widget? micButton;

  /// The hold-to-talk control (see `HoldToTalkButton`), phone only.
  final Widget? holdToTalk;

  final String hintText;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.sm, Spacing.lg, Spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: t.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.card),
              side: BorderSide(color: t.hairline),
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
                    tooltip: l.assistantSend,
                    iconSize: 26,
                    style: IconButton.styleFrom(
                      fixedSize: const Size(56, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.card)),
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
          if (holdToTalk != null) ...[
            const SizedBox(height: Spacing.sm),
            holdToTalk!,
          ],
        ],
      ),
    );
  }
}
