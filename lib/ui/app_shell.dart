import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vehicle_mobile/models/rider_input.dart';
import 'package:vehicle_mobile/services/voice/intercom_audio.dart';
import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/services/voice/voice_triggers.dart';
import 'package:vehicle_mobile/ui/assistant/assistant_screen.dart';
import 'package:vehicle_mobile/ui/faults/faults_screen.dart';
import 'package:vehicle_mobile/ui/phone/phone_tabs.dart';
import 'package:vehicle_mobile/ui/rides/ride_history_screen.dart';
import 'package:vehicle_mobile/ui/settings_screen.dart';

/// Top-level destinations. The phone shows [live], [signals], [record],
/// [diagnostics], [assistant] and [settings]; the computer (web, macOS) shows
/// only [assistant] (Usta), [rides], [faults] and [settings] (D-121 item 3).
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

/// Navigation shell: a Material 3 NavigationBar (NavigationRail on a wide
/// computer window) over the destinations of the current platform.
///
/// Record and Settings keep their state once opened (an active recording and
/// unsaved form input must survive tab switches); the telemetry screens are
/// rebuilt on demand because their state lives in the telemetry store of
/// [phoneTabs]. Assistant keeps its conversation in memory while the shell
/// lives.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.phoneTabs, this.voiceBus, this.intercom, this.voice});

  /// Phone-only destinations; null on web and desktop, which hides them.
  final PhoneTabs? phoneTabs;

  /// Where voice triggers (handlebar push-to-talk, the intercom voice-command
  /// button) are routed; defaults to [VoiceTriggerBus.instance].
  final VoiceTriggerBus? voiceBus;

  /// Android audio/intent bridge; defaults to [IntercomAudio.instance].
  final IntercomAudio? intercom;

  /// Voice front end of the Usta tab (tests inject fakes); created there when null.
  final VoiceController? voice;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Bumped when the Settings destination saves; Record listens to refresh.
  final ValueNotifier<int> _settingsChanged = ValueNotifier<int>(0);
  late final List<ShellTab> _tabs;
  late ShellTab _tab;
  late final Set<ShellTab> _visited;
  late final VoiceTriggerBus _voiceBus;
  late final IntercomAudio _intercom;
  StreamSubscription<RiderInputAction>? _riderInputSubscription;

  @override
  void initState() {
    super.initState();
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

    // Voice triggers bring Usta to the front: the handlebar button (phone,
    // BLE) and the intercom's voice-command button (Android intent).
    _voiceBus.onNeedAssistant = () => _select(ShellTab.assistant);
    _riderInputSubscription = widget.phoneTabs?.riderInputActions?.listen(
        (action) => _voiceBus.emit(triggerOfRiderInput(action)));
    unawaited(bindVoiceCommandIntent(_intercom, _voiceBus));
  }

  @override
  void dispose() {
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
        return AssistantScreen(voice: widget.voice, voiceBus: _voiceBus);
      case ShellTab.rides:
        return const RideHistoryScreen();
      case ShellTab.faults:
        return const FaultsScreen();
      case ShellTab.settings:
        return SettingsScreen(onSaved: () => _settingsChanged.value++);
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
        ShellTab.assistant => (Icons.handyman_outlined, Icons.handyman, 'Usta'),
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
    final wideComputer =
        widget.phoneTabs == null && MediaQuery.sizeOf(context).width >= 720;
    if (wideComputer) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
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
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
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
}
