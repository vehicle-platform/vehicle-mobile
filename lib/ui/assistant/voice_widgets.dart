import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

String _micLabel(AppLocalizations l, VoiceState state) => switch (state) {
      VoiceState.listening => l.assistantMicStop,
      VoiceState.speaking => l.assistantMicSpeaking,
      _ => l.assistantMicStart,
    };

/// 56 px microphone button of the composer (wide layouts). Listening shows a
/// teal ring (pulsing, or static when the system asks for reduced motion).
class MicButton extends StatefulWidget {
  const MicButton({super.key, required this.state, required this.onPressed});

  final VoiceState state;
  final VoidCallback? onPressed;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));

  bool get _listening => widget.state == VoiceState.listening;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRing();
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRing();
  }

  void _syncRing() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_listening && !reduce) {
      if (!_ring.isAnimating) _ring.repeat(reverse: true);
    } else {
      _ring.stop();
      _ring.value = _listening ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final busy = widget.state == VoiceState.preparing ||
        widget.state == VoiceState.finishing;
    final label = _micLabel(context.l10n, widget.state);
    return Semantics(
      label: label,
      button: true,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (_listening)
              AnimatedBuilder(
                animation: _ring,
                builder: (_, __) => Container(
                  key: const ValueKey('mic-ring'),
                  width: 56 + 8 * _ring.value,
                  height: 56 + 8 * _ring.value,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(Radii.card + 4 * _ring.value),
                    border: Border.all(
                        color: t.accent
                            .withValues(alpha: 0.35 + 0.55 * _ring.value),
                        width: 2),
                  ),
                ),
              ),
            IconButton(
              tooltip: label,
              iconSize: 26,
              style: IconButton.styleFrom(
                fixedSize: const Size(56, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.card)),
                backgroundColor:
                    _listening ? t.surfaceRaised : Colors.transparent,
                foregroundColor: _listening ? t.accent : t.textPrimary,
              ),
              icon: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Icon(_listening ? Icons.mic : Icons.mic_none),
              onPressed: busy ? null : widget.onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

/// Large hold-to-talk control for gloves on the phone (D-130 item 3): full
/// width and at least 72 px tall. Hold to talk, release to send; a short tap
/// toggles listening (start, then tap again to send).
class HoldToTalkButton extends StatelessWidget {
  const HoldToTalkButton({
    super.key,
    required this.state,
    required this.onStart,
    required this.onRelease,
    required this.onTap,
  });

  /// Minimum height (touch target for gloves).
  static const double height = 72;

  final VoiceState state;
  final VoidCallback onStart;
  final VoidCallback onRelease;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.vehicle;
    final listening = state == VoiceState.listening;
    final busy = state == VoiceState.preparing || state == VoiceState.finishing;
    final label = listening
        ? l.assistantReleaseToSend
        : busy
            ? l.assistantPreparing
            : l.assistantHoldToTalk;
    final color = listening ? t.accent : t.textPrimary;
    return Semantics(
      button: true,
      label: _micLabel(l, state),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        onLongPressStart: busy ? null : (_) => onStart(),
        onLongPressEnd: busy ? null : (_) => onRelease(),
        child: AnimatedContainer(
          key: const ValueKey('hold-to-talk'),
          duration: Motion.fast,
          curve: Motion.curve,
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: listening ? t.surfaceRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
                color: listening ? t.accent : t.hairline,
                width: listening ? 2 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(listening ? Icons.mic : Icons.mic_none,
                  size: 28, color: color),
              const SizedBox(width: Spacing.md),
              Text(upperFor(context, label),
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge!
                      .copyWith(color: color, letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small status line above the composer: where the sound goes.
class VoiceRouteChip extends StatelessWidget {
  const VoiceRouteChip({super.key, required this.route});

  final VoiceRoute route;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final l = context.l10n;
    final connected = route == VoiceRoute.intercom;
    final color = connected ? t.accent : t.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(connected ? Icons.headset_mic_outlined : Icons.phone_android,
            size: 16, color: color),
        const SizedBox(width: Spacing.xs + 2),
        Text(connected ? l.assistantRouteIntercom : l.assistantRoutePhone,
            style:
                Theme.of(context).textTheme.bodySmall!.copyWith(color: color)),
      ],
    );
  }
}
