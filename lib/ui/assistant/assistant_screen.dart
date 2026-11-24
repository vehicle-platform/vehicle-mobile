import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;

import 'package:vehicle_mobile/models/chat_message.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/chat_client.dart';
import 'package:vehicle_mobile/services/host_resolver.dart';
import 'package:vehicle_mobile/ui/assistant/chat_widgets.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// Example questions of the empty state (the rider talks Turkish to the bike).
const List<String> assistantExampleQuestions = [
  'Son sürüşüm nasıldı?',
  'Son sürüşün özeti',
  'Kayıtlı arızalar var mı?',
];

/// Rider assistant (D-121): a text chat against `POST /chat` of the active
/// host. The server picks one read-only vehicle-mcp tool and phrases its
/// result; this screen only shows the answer and the tool that computed the
/// numbers. It never computes or rephrases a number and adds no advice. The
/// conversation lives in memory only: answers may contain ride data.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    this.settingsStore = const AppSettingsStore(),
    this.client,
    this.sessionId,
  });

  final AppSettingsStore settingsStore;
  final ChatClient? client;

  /// Ride the question is about (opened from a ride screen), sent as `session_id`.
  final String? sessionId;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> with SingleTickerProviderStateMixin {
  late final ChatClient _client;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _sessionId;
  bool _sending = false;

  /// Pulse of the placeholder card while waiting (no typing dots).
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _client = widget.client ?? ChatClient();
    _sessionId = widget.sessionId;
  }

  @override
  void dispose() {
    _pulse.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UstaAvatar(size: 30),
            SizedBox(width: Spacing.md),
            Text('Usta'),
          ],
        ),
        actions: [
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
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                if (_sessionId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        avatar: const Icon(Icons.route, size: 18),
                        label: Text('Ride $_sessionId'),
                        onDeleted: () => setState(() => _sessionId = null),
                      ),
                    ),
                  ),
                Expanded(child: _messages.isEmpty ? _emptyState(context) : _messageList()),
                if (_sending) const LinearProgressIndicator(minHeight: 2),
                AssistantComposer(
                  controller: _controller,
                  sending: _sending,
                  onSend: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageList() => ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
        itemCount: _messages.length + (_sending ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _messages.length) return PendingAnswerCard(pulse: _pulse);
          return ChatBubble(message: _messages[i]);
        },
      );

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const UstaAvatar(size: 56),
            const SizedBox(height: Spacing.lg),
            Text('Merhaba, ben Usta. Ne öğrenmek istersin?',
                textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.xl),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final question in assistantExampleQuestions)
                  ActionChip(
                    label: Text(question),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: () => _send(question),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
            decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(6)),
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
                const UstaAvatar(size: 24),
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
/// [micButton] is the reserved slot for the voice button of the next PR.
class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
    this.micButton,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onSend;

  /// Reserved for the push-to-talk / microphone button (voice is a later PR).
  final Widget? micButton;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.md),
      child: Material(
        color: t.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: t.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.xs, Spacing.xs),
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
                  decoration: const InputDecoration(
                    hintText: 'Bir soru yaz',
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
