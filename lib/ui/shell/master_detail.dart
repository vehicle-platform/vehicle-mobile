import 'package:flutter/material.dart';

import 'package:vehicle_mobile/ui/theme/app_theme.dart';
import 'package:vehicle_mobile/ui/theme/layout.dart';

/// List + detail panes for the wide layout (D-130 item 2). Below [minWidth]
/// only the [master] shows and the screens navigate with routes as before.
class MasterDetail extends StatelessWidget {
  const MasterDetail({
    super.key,
    required this.master,
    required this.detail,
    required this.emptyMessage,
    this.masterWidth = 400,
  });

  /// Smallest pane width that fits a master and a detail side by side.
  static const double minWidth = 720;

  /// Whether a pane of [width] shows two panes.
  static bool fits(double width) => width >= minWidth;

  final Widget master;

  /// The selected item's detail; null shows [emptyMessage].
  final Widget? detail;
  final String emptyMessage;
  final double masterWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (!fits(constraints.maxWidth)) return master;
      final t = context.vehicle;
      return Row(
        children: [
          SizedBox(width: masterWidth, child: master),
          VerticalDivider(width: 1, thickness: 1, color: t.hairline),
          Expanded(
            child: detail ??
                EmptyState(icon: Icons.chevron_left, message: emptyMessage),
          ),
        ],
      );
    });
  }
}
