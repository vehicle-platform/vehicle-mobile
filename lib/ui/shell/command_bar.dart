import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// One entry of the command bar.
class ShellCommand {
  const ShellCommand({required this.label, required this.icon, required this.run});

  final String label;
  final IconData icon;
  final VoidCallback run;
}

/// Builds the entries for the typed [query]; the shell appends the "ask the
/// assistant" entry for a non-empty query.
typedef CommandBuilder = List<ShellCommand> Function(String query);

/// Ctrl/Cmd+K command bar (D-130 item 2): type to jump to a screen or to hand
/// a question to the assistant. Enter runs the first match.
Future<void> showCommandBar(BuildContext context, CommandBuilder commands) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _CommandBar(commands: commands),
  );
}

class _CommandBar extends StatefulWidget {
  const _CommandBar({required this.commands});

  final CommandBuilder commands;

  @override
  State<_CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends State<_CommandBar> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run(ShellCommand command) {
    Navigator.of(context).pop();
    command.run();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.vehicle;
    final items = widget.commands(_query.trim());
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 96, left: Spacing.lg, right: Spacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            color: t.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.card),
              side: BorderSide(color: t.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: l.commandBarTitle,
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.go,
                    decoration: InputDecoration(
                      hintText: l.commandBarHint,
                      prefixIcon: const Icon(Icons.search),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                    onSubmitted: (_) {
                      if (items.isNotEmpty) _run(items.first);
                    },
                  ),
                ),
                Divider(color: t.hairline),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Text(l.commandBarNoMatch,
                        style: Theme.of(context).textTheme.bodySmall),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final c in items)
                          ListTile(
                            dense: true,
                            leading: Icon(c.icon, size: 20),
                            title: Text(c.label),
                            onTap: () => _run(c),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
