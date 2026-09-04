import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/searchable_picker_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

class ProviderKeyEditorDialog extends StatefulWidget {
  const ProviderKeyEditorDialog(
      {super.key,
      required this.providerCatalog,
      required this.onSave,
      this.existing});
  final List<domain.Provider> providerCatalog;
  final ProviderApiKey? existing;
  final void Function(ProviderApiKey updated) onSave;
  @override
  State<ProviderKeyEditorDialog> createState() =>
      ProviderKeyEditorDialogState();
}

class ProviderKeyEditorDialogState extends State<ProviderKeyEditorDialog> {
  late final TextEditingController _controller;
  domain.Provider? _selectedProvider;

  List<domain.Provider> get _targets => widget.providerCatalog;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    final existing = widget.existing;
    if (existing != null) {
      _selectedProvider =
          _targets.where((p) => p.id == existing.provider).firstOrNull;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    final typed = _controller.text.trim();
    final existing = widget.existing;
    if (existing == null && typed.isEmpty) return;
    final selectedProvider = _selectedProvider;
    if (selectedProvider == null) return;
    widget.onSave(
      ProviderApiKey(
        id: existing?.id ?? '',
        owner: existing?.owner ?? '',
        provider: selectedProvider.id,
        apiKey: typed.isEmpty ? (existing?.apiKey ?? '') : typed));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedProvider;
    final title = selected == null
        ? context.l10n.providerScreenSelectProvider
        : context.l10n.providerScreenAddKeyTitle(selected.name.toUpperCase());
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
                      : context.l10n.providerScreenAddKeyBody(
                          selected.name.toUpperCase()),
                  role: TextRole.body,
              ),
              VSpace.x2,
              ProviderTargetPicker(
                  targets: _targets,
                  selectedProvider: selected,
                  onSelected: (p) => setState(() => _selectedProvider = p)),
              VSpace.x2,
              TerminalTextField(
                  controller: _controller,
                  label: context.l10n.providerScreenApiKeyLabel,
                  hint: widget.existing == null
                      ? context.l10n.providerScreenApiKeyLabel
                      : context.l10n.providerScreenApiKeyLeaveBlankHint,
                  obscureText: true),
              VSpace.x2,
              TerminalText(
                  widget.existing == null
                      ? context.l10n.providerScreenApiKeyNotSet
                      : context.l10n.providerScreenApiKeyStoredSecurely,
                  role: TextRole.body,
              ),
            ],
          ),
        ),
      actions: [
        TerminalButton(
            label: context.l10n.actionCancel,
            isPrimary: false,
            onTap: () => Navigator.of(context).pop()),
        HSpace.x2,
        TerminalButton(label: context.l10n.actionSave, onTap: _handleSave),
      ]);
  }
}

class ProviderTargetPicker extends StatelessWidget {
  const ProviderTargetPicker(
      {super.key,
      required this.targets,
      required this.selectedProvider,
      required this.onSelected});
  final List<domain.Provider> targets;
  final domain.Provider? selectedProvider;
  final ValueChanged<domain.Provider> onSelected;

  @override
  Widget build(BuildContext context) => BiosRow(
        label: context.l10n.providerScreenProviderLabel,
        value: selectedProvider?.name.toUpperCase() ??
            context.l10n.providerScreenSelectProvider.toUpperCase(),
        variant: BiosRowVariant.expand,
        onTap: () async {
          final picked = await showDialog<domain.Provider>(
            context: context,
            builder: (dialogContext) =>
                SearchablePickerDialog<domain.Provider>(
              title: dialogContext.l10n.providerScreenSelectProvider,
              items: targets,
              itemLabel: (p) => p.name,
              matches: (p, query) {
                final q = query.toLowerCase();
                return p.name.toLowerCase().contains(q) ||
                    p.providerId.toLowerCase().contains(q);
              },
              itemBuilder: (context, p,
                      {required isSelected, required onTap}) =>
                  ProviderTargetOption(
                provider: p,
                isSelected: isSelected,
                onTap: onTap),
              selectedItem: selectedProvider,
              searchLabel: dialogContext.l10n.providerScreenSearchLabel,
              searchHint: dialogContext.l10n.providerScreenSearchHint,
              emptyLabel: dialogContext.l10n.providerScreenNoProviders,
              noMatchesLabel:
                  dialogContext.l10n.providerScreenSearchNoMatches));
          if (picked != null) onSelected(picked);
        });
}

class ProviderTargetOption extends StatelessWidget {
  const ProviderTargetOption(
      {super.key,
      required this.provider,
      required this.isSelected,
      required this.onTap});
  final domain.Provider provider;
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
              border:
                  Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
              color: isSelected ? colors.primary.withValues(alpha: 0.1) : null),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: TerminalText(
                  provider.name.toUpperCase(),
                  role: TextRole.label,
                  overflow: TextOverflow.ellipsis,
                ),
            ),
            TerminalText(
              provider.providerId,
              role: TextRole.body,
            ),
          ])));
  }
}
