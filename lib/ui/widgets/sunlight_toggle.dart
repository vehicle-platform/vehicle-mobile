import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/ui/theme/theme_controller.dart';

/// One tap between sunlight mode and the previous display choice, for the
/// ride screen (glove-friendly 48 px target). Hidden without a [ThemeScope].
class SunlightToggle extends StatelessWidget {
  const SunlightToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final on = controller.isSunlight;
    final l = context.l10n;
    return IconButton(
      tooltip: on ? l.sunlightModeOn : l.sunlightModeOff,
      isSelected: on,
      onPressed: controller.toggleSunlight,
      icon: const Icon(Icons.wb_sunny_outlined),
      selectedIcon: const Icon(Icons.wb_sunny),
    );
  }
}
