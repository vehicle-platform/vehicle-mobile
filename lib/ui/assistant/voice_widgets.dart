import 'package:flutter/material.dart';

import 'package:vehicle_mobile/services/voice/voice_controller.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// 56 px microphone button of the composer. Listening shows a teal pulsing
/// ring (a static ring when the system asks for reduced motion).
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
    final speaking = widget.state == VoiceState.speaking;
    final label = _listening
        ? 'Dinlemeyi bitir'
        : speaking
            ? 'Okumayı durdur ve konuş'
            : 'Sesle sor';
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
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: t.accent
                            .withValues(alpha: 0.35 + 0.55 * _ring.value),
                        width: 3),
                  ),
                ),
              ),
            IconButton(
              tooltip: label,
              iconSize: 26,
              style: IconButton.styleFrom(
                fixedSize: const Size(56, 56),
                shape: const CircleBorder(),
                backgroundColor: _listening
                    ? t.accent.withValues(alpha: 0.18)
                    : Colors.transparent,
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

/// Small status chip above the composer: where the sound goes.
class VoiceRouteChip extends StatelessWidget {
  const VoiceRouteChip(
      {super.key, required this.label, required this.connected});

  final String label;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final t = context.vehicle;
    final color = connected ? t.accent : t.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.xs + 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.chip + 8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(connected ? Icons.headset_mic_outlined : Icons.phone_android,
              size: 16, color: color),
          const SizedBox(width: Spacing.xs + 2),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: color)),
        ],
      ),
    );
  }
}
