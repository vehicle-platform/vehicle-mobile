import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/app_notification.dart';
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
import 'package:vehicle_mobile/ui/garage/garage_screen.dart';
import 'package:vehicle_mobile/ui/rides/ride_summary_screen.dart';
import 'package:vehicle_mobile/ui/shell/command_bar.dart';
import 'package:vehicle_mobile/ui/shell/master_detail.dart';
import 'package:vehicle_mobile/ui/shell/ride_destination.dart';
import 'package:vehicle_mobile/ui/shell/shell_scope.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/notifications/notification_scope.dart';
import 'package:vehicle_mobile/ui/phone/phone_tabs.dart';
import 'package:vehicle_mobile/ui/rides/ride_history_screen.dart';
import 'package:vehicle_mobile/ui/settings_screen.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';

/// Top-level destinations (D-130 item 2). Ride exists on the phone only.
enum ShellTab { ride, garage, logbook, assistant }

/// Navigation shell (D-130 item 2): Ride (phone only), Garage, Logbook and
/// Assistant; Settings from the header (phone) or the rail (600 px up). Below
/// 600 px a bottom bar; 600-900 px a rail with single panes; from 900 px a rail
/// with list + detail panes, the assistant as a side panel and a Ctrl/Cmd+K
/// command bar. The Ride destination keeps its recording alive once opened and
/// the Assistant keeps its conversation while the shell lives.
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
  /// Bumped when Settings saves; Record listens to refresh.
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
  bool _panelOpen = false;
  bool _twoPane = false;
  bool _assistantMounted = false;
  String? _selectedRide;
  AppNotification? _selectedNotification;

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
            ShellTab.ride,
            ShellTab.garage,
            ShellTab.logbook,
            ShellTab.assistant
          ]
        : const [ShellTab.garage, ShellTab.logbook, ShellTab.assistant];
    // The computer opens on the assistant, the phone on the ride.
    _tab = phone ? ShellTab.ride : ShellTab.assistant;
    _visited = {_tab};
    _assistantMounted = _tab == ShellTab.assistant;

    // Voice triggers bring the assistant to the front: the handlebar button
    // (phone, BLE) and the intercom's voice-command button (Android intent).
    _voiceBus.onNeedAssistant = () {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      _select(ShellTab.assistant);
    };
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

  /// "Ask the assistant" of a notification or the command bar: back to the
  /// shell, assistant destination, question prefilled (not sent).
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
      if (tab == ShellTab.assistant) _assistantMounted = true;
    });
  }

  void _togglePanel() => setState(() {
        _panelOpen = !_panelOpen;
        if (_panelOpen) _assistantMounted = true;
      });

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NotificationScope(
        center: _center,
        onAsk: _askAssistant,
        child: SettingsScreen(
            store: widget.settingsStore,
            onSaved: () => _settingsChanged.value++),
      ),
    ));
  }

  void _openRide(String sessionId) => setState(() => _selectedRide = sessionId);

  void _openNotification(AppNotification n) =>
      setState(() => _selectedNotification = n);

  void _openCommandBar() {
    final l = context.l10n;
    final wide = Breakpoints.isWide(MediaQuery.sizeOf(context).width);
    showCommandBar(context, (query) {
      final q = query.toLowerCase();
      final all = <ShellCommand>[
        for (final tab in _tabs)
          ShellCommand(
            label: l.commandGoTo(_label(l, tab)),
            icon: _entry(tab).$1,
            run: () => _select(tab),
          ),
        ShellCommand(
          label: l.commandGoTo(l.navSettings),
          icon: Icons.tune,
          run: _openSettings,
        ),
        if (wide && _tab != ShellTab.assistant)
          ShellCommand(
            label: _panelOpen ? l.commandClosePanel : l.commandOpenPanel,
            icon: Icons.view_sidebar_outlined,
            run: _togglePanel,
          ),
      ];
      final matches = q.isEmpty
          ? all
          : all.where((c) => c.label.toLowerCase().contains(q)).toList();
      return [
        ...matches,
        if (query.isNotEmpty)
          ShellCommand(
            label: l.commandAsk(l.assistantName, query),
            icon: Icons.keyboard_return,
            run: () => _askAssistant(query, null),
          ),
      ];
    });
  }

  static String _label(AppLocalizations l, ShellTab tab) => switch (tab) {
        ShellTab.ride => l.navRide,
        ShellTab.garage => l.navGarage,
        ShellTab.logbook => l.navLogbook,
        ShellTab.assistant => l.navAssistant,
      };

  static (IconData, IconData) _entry(ShellTab tab) => switch (tab) {
        ShellTab.ride => (Icons.speed_outlined, Icons.speed),
        ShellTab.garage => (Icons.garage_outlined, Icons.garage),
        ShellTab.logbook => (Icons.menu_book_outlined, Icons.menu_book),
        ShellTab.assistant => (Icons.graphic_eq, Icons.graphic_eq),
      };

  Widget _build(ShellTab tab) {
    switch (tab) {
      case ShellTab.ride:
        return RideDestination(
            phone: widget.phoneTabs!, settingsChanged: _settingsChanged);
      case ShellTab.garage:
        return GarageScreen(
          settingsStore: widget.settingsStore,
          twoPane: _twoPane,
          selected: _selectedNotification,
          onOpenNotification: _openNotification,
        );
      case ShellTab.logbook:
        final id = _selectedRide;
        final history = RideHistoryScreen(
          settingsStore: widget.settingsStore,
          onOpenRide: _twoPane ? _openRide : null,
        );
        if (!_twoPane) return history;
        return MasterDetail(
          master: history,
          detail: id == null
              ? null
              : RideSummaryScreen(
                  key: ValueKey(id),
                  sessionId: id,
                  settingsStore: widget.settingsStore),
          emptyMessage: context.l10n.logbookSelectRide,
        );
      case ShellTab.assistant:
        return AssistantScreen(
            settingsStore: widget.settingsStore,
            voice: _voice,
            voiceBus: _voiceBus,
            prefill: _prefill);
    }
  }

  Widget _rail(AppLocalizations l, bool wide, int railIndex) {
    final others = _tabs;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: railIndex,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => _select(others[i]),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (wide && _tab != ShellTab.assistant)
                          _RailAction(
                            icon: Icons.view_sidebar_outlined,
                            label: _panelOpen
                                ? l.panelToggleClose
                                : l.panelToggleOpen,
                            showLabel: false,
                            active: _panelOpen,
                            onTap: _togglePanel,
                          ),
                        if (wide)
                          _RailAction(
                            icon: Icons.search,
                            label: l.commandBarShortcut,
                            onTap: _openCommandBar,
                          ),
                        _RailAction(
                          icon: Icons.tune,
                          label: l.navSettings,
                          onTap: _openSettings,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final tab in others)
                  NavigationRailDestination(
                    icon: Icon(_entry(tab).$1),
                    selectedIcon: Icon(_entry(tab).$2),
                    label: Text(_label(l, tab)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.vehicle;
    final index = _tabs.indexOf(_tab);
    final width = MediaQuery.sizeOf(context).width;
    final wide = Breakpoints.isWide(width);
    final railLayout = Breakpoints.usesRail(width);

    final others = [for (final tab in _tabs) if (tab != ShellTab.assistant) tab];
    final mainStack = IndexedStack(
      index: _tab == ShellTab.assistant ? 0 : others.indexOf(_tab),
      children: [
        for (final tab in others)
          if (_visited.contains(tab))
            KeyedSubtree(key: ValueKey(tab), child: _build(tab))
          else
            const SizedBox.shrink(),
      ],
    );

    final content = LayoutBuilder(builder: (context, c) {
      final avail = c.maxWidth;
      final assistantFull = _tab == ShellTab.assistant;
      final showPanel = wide && !assistantFull && _panelOpen;
      const panelWidth = 400.0;
      final mainWidth = assistantFull ? 0.0 : (showPanel ? avail - panelWidth : avail);
      _twoPane = wide && MasterDetail.fits(mainWidth);
      final assistantWidth = assistantFull ? avail : (showPanel ? panelWidth : 0.0);
      return Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: mainWidth,
            child: Offstage(offstage: assistantFull, child: mainStack),
          ),
          if (_assistantMounted)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: assistantWidth == 0 ? avail : assistantWidth,
              child: Offstage(
                offstage: assistantWidth == 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: showPanel
                        ? Border(left: BorderSide(color: t.hairline))
                        : null,
                  ),
                  child: KeyedSubtree(
                      key: const ValueKey('assistant'),
                      child: _build(ShellTab.assistant)),
                ),
              ),
            ),
        ],
      );
    });

    final Widget scaffold;
    if (railLayout) {
      scaffold = Scaffold(
        body: Row(
          children: [
            _rail(l, wide, index),
            VerticalDivider(width: 1, thickness: 1, color: t.hairline),
            Expanded(child: content),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        body: content,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.hairline))),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => _select(_tabs[i]),
            destinations: [
              for (final tab in _tabs)
                NavigationDestination(
                  icon: Icon(_entry(tab).$1),
                  selectedIcon: Icon(_entry(tab).$2),
                  label: _label(l, tab),
                ),
            ],
          ),
        ),
      );
    }
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          _openCommandBar,
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
          _openCommandBar,
    };
    return ShellScope(
      openSettings: _openSettings,
      openCommandBar: _openCommandBar,
      child: NotificationScope(
        center: _center,
        onAsk: _askAssistant,
        child: CallbackShortcuts(
          bindings: shortcuts,
          child: Focus(autofocus: true, child: scaffold),
        ),
      ),
    );
  }
}

/// Icon + small label button at the foot of the rail.
class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showLabel = true,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showLabel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final color = active ? t.accent : t.textSecondary;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 80,
          height: Spacing.touchTarget + (showLabel ? 16 : 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              if (showLabel)
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium!
                        .copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
