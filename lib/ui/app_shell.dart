import 'package:flutter/material.dart';

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
  const AppShell({super.key, this.phoneTabs});

  /// Phone-only destinations; null on web and desktop, which hides them.
  final PhoneTabs? phoneTabs;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Bumped when the Settings destination saves; Record listens to refresh.
  final ValueNotifier<int> _settingsChanged = ValueNotifier<int>(0);
  late final List<ShellTab> _tabs;
  late ShellTab _tab;
  late final Set<ShellTab> _visited;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
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
        return const AssistantScreen();
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
