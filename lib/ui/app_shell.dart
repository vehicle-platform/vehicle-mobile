import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vehicle_mobile/models/rider_input.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/notifications/local_notifier.dart';
import 'package:vehicle_mobile/services/notifications/notification_center.dart';
import 'package:vehicle_mobile/services/notifications/platform_notifications.dart';
import 'package:vehicle_mobile/services/voice/critical_announcer.dart';
import 'package:vehicle_mobile/services/voice/intercom_audio.dart';
import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/services/voice/voice_triggers.dart';
import 'package:vehicle_mobile/ui/assistant/assistant_screen.dart';
import 'package:vehicle_mobile/ui/faults/faults_screen.dart';
import 'package:vehicle_mobile/ui/notifications/notification_scope.dart';
import 'package:vehicle_mobile/ui/phone/phone_tabs.dart';
import 'package:vehicle_mobile/ui/rides/ride_history_screen.dart';
import 'package:vehicle_mobile/ui/settings_screen.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';

/// Top-level destinations. The phone shows [live], [signals], [record],
/// [diagnostics], [assistant] and [settings]; the computer (web, macOS) shows
/// only [assistant] (Sürüş Asistanı), [rides], [faults] and [settings] (D-121 item 3).
enum ShellTab {
  live,
  signals,
  record,
  diagnostics,
  assistant,
  rides,
  faults,
  settings
}

/// Navigation shell: a Material 3 NavigationBar below 600 px of width (also in
/// a phone browser or a narrow window), a NavigationRail from 600 px up; the
/// destinations depend on the platform. Wide screens are width-limited per
/// screen (`ContentColumn`).
///
/// Record and Settings keep their state once opened (an active recording and
/// unsaved form input must survive tab switches); the telemetry screens are
/// rebuilt on demand because their state lives in the telemetry store of
/// [phoneTabs]. Assistant keeps its conversation in memory while the shell
/// lives.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.phoneTabs,
    this.voiceBus,
    this.intercom,
    this.voice,
    this.notifications,
    this.localNotifier,
    this.backgroundPull = true,
    this.settingsStore = const AppSettingsStore(),
  });

  /// Phone-only destinations; null on web and desktop, which hides them.
  final PhoneTabs? phoneTabs;

  /// Where voice triggers (handlebar push-to-talk, the intercom voice-command
  /// button) are routed; defaults to [VoiceTriggerBus.instance].
  final VoiceTriggerBus? voiceBus;

  /// Android audio/intent bridge; defaults to [IntercomAudio.instance].
  final IntercomAudio? intercom;

  /// Voice front end of the assistant tab (tests inject fakes); created here
  /// when null. The shell owns it so critical notifications can be spoken
  /// while another tab is open.
  final VoiceController? voice;

  /// The notification inbox state (D-123); created here when null.
  final NotificationCenter? notifications;

  /// System notifications (Android); null picks the platform one.
  final LocalNotifier? localNotifier;

  /// Host and session source of the server screens (tests inject one).
  final AppSettingsStore settingsStore;

  /// Registers the Android periodic pull; tests switch it off.
  final bool backgroundPull;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  /// Bumped when the Settings destination saves; Record listens to refresh.
  final ValueNotifier<int> _settingsChanged = ValueNotifier<int>(0);
  late final List<ShellTab> _tabs;
  late ShellTab _tab;
  late final Set<ShellTab> _visited;
  late final VoiceTriggerBus _voiceBus;
  late final IntercomAudio _intercom;
  StreamSubscription<RiderInputAction>? _riderInputSubscription;
  late final VoiceController _voice;
  late final bool _ownsVoice;
  late final NotificationCenter _center;
  late final bool _ownsCenter;
  final ValueNotifier<AssistantPrefill?> _prefill = ValueNotifier(null);
  int _prefillSeq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsVoice = widget.voice == null;
    _voice = widget.voice ?? VoiceController();
    _ownsCenter = widget.notifications == null;
    _center = widget.notifications ??
        NotificationCenter(announcer: CriticalAnnouncer(speak: _voice.speak));
    _center.start();
    unawaited(_setUpSystemNotifications());
    _voiceBus = widget.voiceBus ?? VoiceTriggerBus.instance;
    _intercom = widget.intercom ?? IntercomAudio.instance;
    final phone = widget.phoneTabs != null;
    _tabs = phone
        ? const [
            ShellTab.live,
            ShellTab.signals,
            ShellTab.record,
            ShellTab.diagnostics,
            ShellTab.assistant,
            ShellTab.settings,
          ]
        : const [
            ShellTab.assistant,
            ShellTab.rides,
            ShellTab.faults,
            ShellTab.settings
          ];
    _tab = _tabs.first;
    _visited = {_tab};

    // Voice triggers bring the assistant to the front: the handlebar button (phone,
    // BLE) and the intercom's voice-command button (Android intent).
    _voiceBus.onNeedAssistant = () => _select(ShellTab.assistant);
    _riderInputSubscription = widget.phoneTabs?.riderInputActions?.listen(
        (action) => _voiceBus.emit(triggerOfRiderInput(action)));
    unawaited(bindVoiceCommandIntent(_intercom, _voiceBus));
  }

  /// Android: permission (13+), channels and the periodic background pull.
  /// Failing here never affects the app (web and desktop do nothing).
  Future<void> _setUpSystemNotifications() async {
    try {
      final notifier = widget.localNotifier ?? createLocalNotifier();
      await notifier.init();
      await notifier.requestPermission();
      if (widget.backgroundPull) await registerBackgroundPull();
    } catch (_) {
      // Notifications stay in-app.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _center.resumed();
  }

  /// "Sürüş Asistanı'na sor" of a notification: back to the shell, assistant
  /// tab, question prefilled (not sent).
  void _askAssistant(String question, String? sessionId) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _prefill.value = AssistantPrefill(++_prefillSeq, question, sessionId);
    _select(ShellTab.assistant);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _center.stop();
    if (_ownsCenter) _center.dispose();
    if (_ownsVoice) _voice.dispose();
    _prefill.dispose();
    _riderInputSubscription?.cancel();
    _voiceBus.onNeedAssistant = null;
    _intercom.stopListeningVoiceCommand();
    widget.phoneTabs?.dispose();
    _settingsChanged.dispose();
    super.dispose();
  }

  void _select(ShellTab tab) {
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  Widget _build(ShellTab tab) {
    final phone = widget.phoneTabs;
    switch (tab) {
      case ShellTab.live:
        return phone!.live(onOpenRecord: () => _select(ShellTab.record));
      case ShellTab.signals:
        return phone!.signals();
      case ShellTab.record:
        return phone!.record(settingsChanged: _settingsChanged);
      case ShellTab.diagnostics:
        return phone!.diagnostics();
      case ShellTab.assistant:
        return AssistantScreen(
            settingsStore: widget.settingsStore,
            voice: _voice,
            voiceBus: _voiceBus,
            prefill: _prefill);
      case ShellTab.rides:
        return RideHistoryScreen(settingsStore: widget.settingsStore);
      case ShellTab.faults:
        return FaultsScreen(settingsStore: widget.settingsStore);
      case ShellTab.settings:
        return SettingsScreen(
            store: widget.settingsStore, onSaved: () => _settingsChanged.value++);
    }
  }

  /// Tabs whose state must outlive a tab switch once they were opened.
  bool _keepAlive(ShellTab tab) =>
      tab == ShellTab.record ||
      tab == ShellTab.settings ||
      tab == ShellTab.assistant;

  static (IconData, IconData, String) _entry(ShellTab tab) => switch (tab) {
        ShellTab.live => (Icons.speed_outlined, Icons.speed, 'Live'),
        ShellTab.signals => (Icons.sensors_outlined, Icons.sensors, 'Signals'),
        ShellTab.record => (
            Icons.fiber_manual_record_outlined,
            Icons.fiber_manual_record,
            'Record'
          ),
        ShellTab.diagnostics => (
            Icons.monitor_heart_outlined,
            Icons.monitor_heart,
            'Diagnostics'
          ),
        ShellTab.assistant => (
            Icons.chat_bubble_outline,
            Icons.chat_bubble,
            'Asistan'
          ),
        ShellTab.rides => (Icons.route_outlined, Icons.route, 'Rides'),
        ShellTab.faults => (
            Icons.report_problem_outlined,
            Icons.report_problem,
            'Faults'
          ),
        ShellTab.settings => (
            Icons.settings_outlined,
            Icons.settings,
            'Settings'
          ),
      };

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexOf(_tab);
    final body = IndexedStack(
      index: index,
      children: [
        for (final tab in _tabs)
          if (tab == _tab || (_keepAlive(tab) && _visited.contains(tab)))
            KeyedSubtree(key: ValueKey(tab), child: _build(tab))
          else
            const SizedBox.shrink(),
      ],
    );
    final width = MediaQuery.sizeOf(context).width;
    final Widget scaffold;
    if (Breakpoints.usesRail(width)) {
      scaffold = Scaffold(
        body: Row(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: index,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (i) => _select(_tabs[i]),
                      destinations: [
                        for (final tab in _tabs)
                          NavigationRailDestination(
                            icon: Icon(_entry(tab).$1),
                            selectedIcon: Icon(_entry(tab).$2),
                            label: Text(_entry(tab).$3),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => _select(_tabs[i]),
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(
                icon: Icon(_entry(tab).$1),
                selectedIcon: Icon(_entry(tab).$2),
                label: _entry(tab).$3,
              ),
          ],
        ),
      );
    }
    return NotificationScope(
        center: _center, onAsk: _askAssistant, child: scaffold);
  }
}
