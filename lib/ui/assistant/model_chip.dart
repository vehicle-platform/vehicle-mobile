import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/assistant_provider.dart';
import 'package:vehicle_mobile/services/app_settings.dart';
import 'package:vehicle_mobile/services/assistant_provider_client.dart';
import 'package:vehicle_mobile/ui/settings/assistant_model_screen.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// `label · model` of the selected provider (D-127 item 1). The model falls
/// back to the provider's default model when the user never picked one.
String activeModelText(
    AssistantChoice choice, List<AssistantProvider> providers) {
  final provider = providers.where((p) => p.id == choice.provider).firstOrNull;
  final label = provider?.label ?? choice.provider;
  final model = (choice.model?.isNotEmpty ?? false)
      ? choice.model
      : provider?.defaultModel;
  return model == null || model.isEmpty ? label : '$label · $model';
}

/// Compact chip in the assistant header naming the selected provider and
/// model. Tapping opens [AssistantModelScreen]; the chip reloads when that
/// screen closes. Renders nothing when the host is not set up, signed out or
/// an older server has no `/assistant/provider` route.
class ActiveModelChip extends StatefulWidget {
  const ActiveModelChip({super.key, required this.settingsStore, this.client});

  final AppSettingsStore settingsStore;
  final AssistantProviderClient? client;

  @override
  State<ActiveModelChip> createState() => _ActiveModelChipState();
}

class _ActiveModelChipState extends State<ActiveModelChip> {
  late final AssistantProviderClient _client =
      widget.client ?? AssistantProviderClient();
  String? _text;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<(String, String)?> _target() async {
    final s = await widget.settingsStore.load();
    final token = s.apiToken ?? '';
    if (!s.isServerConfigured || token.isEmpty) return null;
    return (s.serverBaseUrl!, token);
  }

  Future<void> _load() async {
    String? text;
    try {
      final target = await _target();
      if (target != null) {
        final choice =
            await _client.current(baseUrl: target.$1, token: target.$2);
        if (choice.isSuccess) {
          final providers =
              await _client.providers(baseUrl: target.$1, token: target.$2);
          text = activeModelText(choice.value!, providers.value ?? const []);
        }
      }
    } catch (_) {
      text = null;
    }
    if (mounted) setState(() => _text = text);
  }

  Future<void> _open() async {
    final target = await _target();
    if (target == null || !mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => AssistantModelScreen(
            baseUrl: target.$1, token: target.$2, client: _client)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (text == null) return const SizedBox.shrink();
    final t = context.vehicle;
    return Semantics(
      button: true,
      label: context.l10n.assistantModelChipLabel(text),
      child: InkWell(
        key: const ValueKey('active-model-chip'),
        borderRadius: BorderRadius.circular(Radii.chip),
        onTap: _open,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.chip),
            border: Border.all(color: t.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 12, color: t.textSecondary),
              const SizedBox(width: Spacing.xs),
              Flexible(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall!
                        .copyWith(color: t.textSecondary)),
              ),
              Icon(Icons.chevron_right, size: 14, color: t.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
