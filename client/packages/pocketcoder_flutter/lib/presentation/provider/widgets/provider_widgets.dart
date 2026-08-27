import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
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
    if (_selectedProvider == null) return;
    widget.onSave(
      ProviderApiKey(
        id: existing?.id ?? '',
        owner: existing?.owner ?? '',
        provider: _selectedProvider!.id,
        apiKey: typed.isEmpty ? (existing?.apiKey ?? '') : typed,
      ),
    );
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
                  alpha: 0.7),
              VSpace.x2,
              ProviderTargetPicker(
                  targets: _targets,
                  selectedProvider: selected,
                  onSelected: (p) => setState(() => _selectedProvider = p)),
              VSpace.x2,
              TerminalTextField(
                  controller: _controller,
                  label: 'API key',
                  hint: widget.existing == null
                      ? 'API key'
                      : 'Leave blank to keep the existing key',
                  obscureText: true),
              VSpace.x2,
              TerminalText(
                  widget.existing == null
                      ? '(not set)'
                      : 'Existing key is stored securely; enter a new key to replace it.',
                  alpha: 0.5),
            ]),
      ),
      actions: [
        TerminalButton(
            label: context.l10n.actionCancel,
            isPrimary: false,
            onTap: () => Navigator.of(context).pop()),
        HSpace.x2,
        TerminalButton(label: context.l10n.actionSave, onTap: _handleSave),
      ],
    );
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
        label: 'PROVIDER',
        value: selectedProvider?.name.toUpperCase() ??
            context.l10n.providerScreenSelectProvider.toUpperCase(),
        variant: BiosRowVariant.expand,
        onTap: () async {
          final picked = await showDialog<domain.Provider>(
              context: context,
              builder: (_) => _ProviderTargetSearchDialog(
                  targets: targets, selectedProvider: selectedProvider));
          if (picked != null) onSelected(picked);
        },
      );
}

class _ProviderTargetSearchDialog extends StatefulWidget {
  const _ProviderTargetSearchDialog(
      {required this.targets, required this.selectedProvider});
  final List<domain.Provider> targets;
  final domain.Provider? selectedProvider;
  @override
  State<_ProviderTargetSearchDialog> createState() =>
      _ProviderTargetSearchDialogState();
}

class _ProviderTargetSearchDialogState
    extends State<_ProviderTargetSearchDialog> {
  final _searchController = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<domain.Provider> get _filtered {
    if (_query.isEmpty) return widget.targets;
    final q = _query.toLowerCase();
    return widget.targets
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.providerId.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return TerminalDialog(
      title: context.l10n.providerScreenSelectProvider,
      content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: widget.targets.isEmpty
              ? Center(
                  child: TerminalText(context.l10n.providerScreenNoProviders,
                      alpha: 0.5))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      TerminalTextField(
                          controller: _searchController,
                          label: context.l10n.providerScreenSearchLabel,
                          hint: context.l10n.providerScreenSearchHint,
                          onChanged: (v) => setState(() => _query = v)),
                      VSpace.x2,
                      Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: TerminalText(
                                      context
                                          .l10n.providerScreenSearchNoMatches,
                                      alpha: 0.5))
                              : ListView(children: [
                                  for (final p in filtered)
                                    ProviderTargetOption(
                                        provider: p,
                                        isSelected:
                                            widget.selectedProvider?.id == p.id,
                                        onTap: () =>
                                            Navigator.of(context).pop(p))
                                ])),
                    ])),
      actions: [
        TerminalButton(
            label: context.l10n.actionCancel,
            isPrimary: false,
            onTap: () => Navigator.of(context).pop())
      ],
    );
  }
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
                child: TerminalText(provider.name.toUpperCase(),
                    weight: TerminalTextWeight.heavy,
                    overflow: TextOverflow.ellipsis)),
            TerminalText.mini(provider.providerId, alpha: 0.5)
          ]),
        ));
  }
}
