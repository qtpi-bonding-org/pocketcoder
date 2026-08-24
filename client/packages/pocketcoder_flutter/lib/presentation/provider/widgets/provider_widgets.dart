import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';

/// Stateful edit dialog body for a single [ProviderKey].
///
/// Lets the user pick a harness (by `cliId`, which is what
/// `ProviderKey.provider` holds) and enter a single generic `API_KEY` env
/// var value — there's no HarnessModel/Harnesse schema-driven env var list
/// in the seeded catalog, so a single field is the right scope.
class ProviderKeyEditorDialog extends StatefulWidget {
  const ProviderKeyEditorDialog({
    super.key,
    required this.harnesses,
    required this.onSave,
    this.existing,
  });

  final List<Harnesse> harnesses;
  final ProviderKey? existing;
  final void Function(ProviderKey updated) onSave;

  @override
  State<ProviderKeyEditorDialog> createState() =>
      ProviderKeyEditorDialogState();
}

class ProviderKeyEditorDialogState extends State<ProviderKeyEditorDialog> {
  late final TextEditingController _apiKeyController;
  Harnesse? _selectedHarness;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    final initialEnvValue = _envValueFrom(existing.envVars);
    _apiKeyController.text = initialEnvValue ?? '';
    for (final h in widget.harnesses) {
      if (h.cliId == existing.provider) {
        _selectedHarness = h;
        break;
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final value = _apiKeyController.text.trim();
    if (value.isEmpty) return;
    if (_selectedHarness == null) return;

    final existing = widget.existing;
    widget.onSave(
      ProviderKey(
        id: existing?.id ?? '',
        user: existing?.user ?? '',
        provider: _selectedHarness?.cliId ?? '',
        envVars: <String, dynamic>{'API_KEY': value},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final harnesses = widget.harnesses;
    final selected = _selectedHarness;

    final title = selected == null
        ? context.l10n.providerScreenSelectProvider
        : context.l10n.providerScreenAddKeyTitle(selected.name.toUpperCase());

    final initialEntry =
        widget.existing == null ? <String, String>{} : <String, String>{};
    final existingEnv = _envValueFrom(widget.existing?.envVars);
    if (existingEnv != null) {
      initialEntry['API_KEY'] = existingEnv;
    }

    return TerminalDialog(
      title: title,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalText(
              selected == null
                  ? context.l10n.providerScreenAddKey
                  : context.l10n.providerScreenAddKeyBody(selected.name),
              alpha: 0.7,
            ),
            VSpace.x2,
            ProviderHarnessPicker(
              harnesses: harnesses,
              selectedHarnessId: selected?.id,
              onSelected: (h) => setState(() => _selectedHarness = h),
            ),
            VSpace.x2,
            TerminalTextField(
              controller: _apiKeyController,
              label: 'API_KEY',
              hint: 'API_KEY',
              obscureText: true,
            ),
            VSpace.x2,
            Container(
              padding: EdgeInsets.all(AppSizes.space),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TerminalText.tiny(
                    'CURRENT VALUE',
                    color: colors.onSurface,
                  ),
                  VSpace.x1,
                  TerminalText(
                    existingEnv == null
                        ? '(not set)'
                        : _maskKeyPreview(initialEntry),
                    color: colors.onSurface,
                    alpha: existingEnv == null ? 0.5 : 1.0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TerminalButton(
          label: context.l10n.actionCancel,
          isPrimary: false,
          onTap: () => Navigator.of(context).pop(),
        ),
        HSpace.x2,
        TerminalButton(
          label: context.l10n.actionSave,
          onTap: _handleSave,
        ),
      ],
    );
  }

  String _maskKeyPreview(Map<String, String> envVars) {
    if (envVars.isEmpty) return '***';
    final firstValue = envVars.values.first;
    if (firstValue.length > 8) {
      final head = firstValue.substring(0, 4);
      final tail = firstValue.substring(firstValue.length - 4);
      return '$head..$tail';
    }
    return '****';
  }

  /// Best-effort extraction of an `API_KEY` value from the dynamic-typed
  /// `ProviderKey.envVars` field (a JSON-deserialized map of unknown shape).
  /// Returns `null` when nothing usable is found so the caller can fall back.
  String? _envValueFrom(dynamic envVars) {
    if (envVars == null) return null;
    if (envVars is Map) {
      for (final entry in envVars.entries) {
        final key = entry.key.toString();
        final value = entry.value.toString();
        if (key.toUpperCase().contains('API_KEY') ||
            key.toUpperCase().contains('APIKEY') ||
            key.toUpperCase().contains('TOKEN') ||
            key.toUpperCase().contains('KEY')) {
          return value;
        }
      }
      if (envVars.isNotEmpty) {
        final firstValue = envVars.values.first;
        if (firstValue != null) return firstValue.toString();
      }
    }
    return null;
  }
}

class ProviderHarnessPicker extends StatelessWidget {
  const ProviderHarnessPicker({
    super.key,
    required this.harnesses,
    required this.selectedHarnessId,
    required this.onSelected,
  });

  final List<Harnesse> harnesses;
  final String? selectedHarnessId;
  final ValueChanged<Harnesse> onSelected;

  @override
  Widget build(BuildContext context) {
    return BiosRow(
      label: 'HARNESS',
      value: _currentValueLabel(context),
      variant: BiosRowVariant.expand,
      onTap: () async {
            final picked = await showDialog<Harnesse>(
              context: context,
              builder: (dialogContext) => TerminalDialog(
                title: context.l10n.providerScreenSelectProvider,
                content: SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: harnesses.isEmpty
                      ? Center(
                          child: TerminalText(
                            context.l10n.providerScreenNoProviders,
                            alpha: 0.5,
                          ),
                        )
                      : ListView(
                          children: [
                            for (final h in harnesses)
                              ProviderHarnessOption(
                                harness: h,
                                isSelected: selectedHarnessId == h.id,
                                onTap: () => Navigator.of(dialogContext).pop(h),
                              ),
                          ],
                        ),
                ),
                actions: [
                  TerminalButton(
                    label: context.l10n.actionCancel,
                    isPrimary: false,
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            );
            if (picked != null) onSelected(picked);
          },
    );
  }

  String _currentValueLabel(BuildContext context) {
    for (final h in harnesses) {
      if (h.id == selectedHarnessId) {
        return h.name.toUpperCase();
      }
    }
    return context.l10n.providerScreenSelectProvider.toUpperCase();
  }
}

class ProviderHarnessOption extends StatelessWidget {
  const ProviderHarnessOption({
    super.key,
    required this.harness,
    required this.isSelected,
    required this.onTap,
  });

  final Harnesse harness;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSizes.space),
        margin: EdgeInsets.only(bottom: AppSizes.space * 0.5),
        decoration: BoxDecoration(
          border: Border.all(
            color: colors.onSurface.withValues(alpha: 0.2),
          ),
          color: isSelected ? colors.primary.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TerminalText(
                harness.name.toUpperCase(),
                weight: TerminalTextWeight.heavy,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TerminalText.mini(
              harness.cliId,
              alpha: 0.5,
            ),
          ],
        ),
      ),
    );
  }
}
