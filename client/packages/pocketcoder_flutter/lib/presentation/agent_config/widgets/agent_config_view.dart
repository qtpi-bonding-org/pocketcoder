import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_state.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

class AgentConfigView extends StatelessWidget {
  const AgentConfigView({super.key, required this.state, required this.providerState, required this.onSave, required this.onDelete});
  final AgentConfigState state;
  final ProviderState providerState;
  final Future<void> Function(PocoConfig) onSave;
  final Future<void> Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(title: context.l10n.agentConfigTitle, activePillar: NavPillar.configure, showBack: true, body: BiosFrame(title: context.l10n.agentConfigRegistry, child: _buildBody(context, state)));
  }

  Widget _buildBody(BuildContext context, AgentConfigState state) {
    if (state.isLoading && state.configs.isEmpty) {
      return Center(
        child: TerminalLoadingIndicator(label: context.l10n.agentSearching),
      );
    }

    if (state.isFailure && state.configs.isEmpty) {
      return Center(
        child: TerminalText(
          context.l10n.agentConfigErrorPrefix(
            state.error?.toString() ?? context.l10n.errorGeneric,
          ),
          color: context.terminalColors.warning,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child: TerminalButton(
            label: context.l10n.actionAddNew,
            onTap: () => _openEditor(context, null),
          ),
        ),
        Expanded(
          child: state.configs.isEmpty
              ? Center(
                  child: TerminalText(
                    context.l10n.agentConfigEmpty,
                    alpha: 0.5,
                  ),
                )
              : ListView.builder(
                  itemCount: state.configs.length,
                  itemBuilder: (context, index) {
                    final config = state.configs[index];
                    final isDefault = config.isDefault ?? false;
                    return BiosRow(
                      label: config.name.toUpperCase(),
                      value: isDefault
                          ? context.l10n.agentConfigDefaultBadge
                          : _harnessModelLabelFor(context, config),
                      hasBadge: isDefault,
                      onTap: () => _openEditor(context, config),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _harnessModelLabelFor(BuildContext context, PocoConfig config) => config.harnessModel.toUpperCase();

  void _openEditor(BuildContext context, PocoConfig? existing) {
    // showDialog pushes a route that is a SIBLING of the route holding
    // AgentConfigScreen's MultiBlocProvider, not a descendant of it — so
    // BlocBuilder<AgentConfigCubit>/<ProviderCubit> inside the dialog
    // subtree (the prompt/harness_model pickers) can't find those cubits
    // via the outer context. Capture them here and re-provide them inside
    // the dialog's own subtree.
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AgentConfigEditorDialog(
            existing: existing,
            prompts: state.prompts,
            models: providerState.harnessModels,
            onSave: (updated) {
              onSave(updated);
              Navigator.of(dialogContext).pop();
            },
            onDelete: existing != null && existing.id.isNotEmpty
                ? () async {
                    final confirmed = await _confirmDelete(
                      dialogContext,
                      existing,
                    );
                    if (confirmed == true) {
                      onDelete(existing.id);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    }
                  }
                : null,
        );
      },
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext dialogContext,
    PocoConfig existing,
  ) {
    return showDialog<bool>(
      context: dialogContext,
      builder: (confirmContext) => TerminalDialog(
        title: dialogContext.l10n.agentConfigDeleteConfirmTitle,
        content: TerminalText(
          dialogContext.l10n.agentConfigDeleteConfirmBody(
            existing.name.toUpperCase(),
          ),
        ),
        actions: [
          TerminalButton(
            label: dialogContext.l10n.actionCancel,
            isPrimary: false,
            onTap: () => Navigator.of(confirmContext).pop(false),
          ),
          HSpace.x2,
          TerminalButton(
            label: dialogContext.l10n.agentConfigDelete,
            onTap: () => Navigator.of(confirmContext).pop(true),
          ),
        ],
      ),
    );
  }
}

/// Edit dialog body for a single PocoConfig.
///
/// Stateful so the local edits (text field value, picker selections,
/// isDefault toggle, mode) re-render the dialog in-place without
/// round-tripping through the cubit. The save callback receives a fully
/// constructed [PocoConfig] with the user's selections applied.
class _AgentConfigEditorDialog extends StatefulWidget {
  const _AgentConfigEditorDialog({
    required this.existing,
    required this.prompts,
    required this.models,
    required this.onSave,
    this.onDelete,
  });

  final PocoConfig? existing;
  final List<Prompt> prompts;
  final List<HarnessModel> models;
  final void Function(PocoConfig updated) onSave;
  final VoidCallback? onDelete;

  @override
  State<_AgentConfigEditorDialog> createState() =>
      _AgentConfigEditorDialogState();
}

class _AgentConfigEditorDialogState extends State<_AgentConfigEditorDialog> {
  late final TextEditingController _nameController;
  String? _harnessModelId;
  String? _systemPromptId;
  PocoConfigMode? _mode;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _harnessModelId = existing?.harnessModel;
    _systemPromptId = existing?.systemPrompt;
    _mode = existing?.mode;
    _isDefault = existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_nameController.text.trim().isEmpty) return;
    final existing = widget.existing;
    widget.onSave(PocoConfig(
      id: existing?.id ?? '',
      name: _nameController.text.trim(),
      harnessModel: _harnessModelId ?? '',
      systemPrompt: _systemPromptId,
      workspaceFolders: existing?.workspaceFolders,
      acpMcpServers: existing?.acpMcpServers,
      isDefault: _isDefault,
      mode: _mode,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return TerminalDialog(
      title: existing == null
          ? context.l10n.agentConfigTitle
          : context.l10n.agentConfigDialogTitle(existing.name.toUpperCase()),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: 300,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TerminalTextField(
                controller: _nameController,
                label: context.l10n.agentConfigNameLabel,
              ),
              VSpace.x2,
              _PromptPicker(
                prompts: widget.prompts,
                selectedPromptId: _systemPromptId,
                onSelected: (id) => setState(() => _systemPromptId = id),
              ),
              VSpace.x2,
              _HarnessModelPicker(
                models: widget.models,
                selectedHarnessModelId: _harnessModelId,
                onSelected: (id) => setState(() => _harnessModelId = id),
              ),
              VSpace.x2,
              _ModePicker(
                selectedMode: _mode,
                onSelected: (mode) => setState(() => _mode = mode),
              ),
              VSpace.x2,
              _IsDefaultToggle(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              if (widget.onDelete case final onDelete?) ...[
                VSpace.x2,
                TerminalButton(
                  label: context.l10n.agentConfigDelete,
                  isPrimary: false,
                  onTap: onDelete,
                ),
              ],
            ],
          ),
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
}

class _IsDefaultToggle extends StatelessWidget {
  const _IsDefaultToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Row(
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
        ),
        HSpace.x2,
        Expanded(
          child: TerminalText(
            context.l10n.agentConfigIsDefaultLabel,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _PromptPicker extends StatelessWidget {
  const _PromptPicker({required this.prompts, required this.selectedPromptId, required this.onSelected});
  final List<Prompt> prompts; final String? selectedPromptId; final ValueChanged<String?> onSelected;
  @override Widget build(BuildContext context) {
    final selected = prompts.where((p) => p.id == selectedPromptId).firstOrNull;
    return _SelectionField(label: context.l10n.agentConfigPromptLabel, currentValue: selected?.name.toUpperCase() ?? context.l10n.agentConfigSelectPrompt.toUpperCase(), onTap: () async {
      final picked = await _showListDialog<String>(context, title: context.l10n.agentConfigSelectPrompt, emptyLabel: context.l10n.agentConfigNoPrompts, items: prompts.map((p)=>(id:p.id,label:p.name)).toList(), initialValue:selectedPromptId);
      if (picked != null) onSelected(picked);
    });
  }
}

class _HarnessModelPicker extends StatelessWidget {
  const _HarnessModelPicker({required this.models, required this.selectedHarnessModelId, required this.onSelected});
  final List<HarnessModel> models; final String? selectedHarnessModelId; final ValueChanged<String?> onSelected;
  @override Widget build(BuildContext context) {
    final selected = models.where((m) => m.id == selectedHarnessModelId).firstOrNull;
    return _SelectionField(label: context.l10n.agentConfigHarnessModelLabel, currentValue: selected?.harnessModelId.toUpperCase() ?? context.l10n.agentConfigSelectHarnessModel.toUpperCase(), onTap: () async {
      final picked = await _showListDialog<String>(context, title: context.l10n.agentConfigSelectHarnessModel, emptyLabel: context.l10n.agentConfigNoHarnessModels, items: models.map((m)=>(id:m.id,label:m.harnessModelId.toUpperCase())).toList(), initialValue:selectedHarnessModelId);
      if (picked != null) onSelected(picked);
    });
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.selectedMode, required this.onSelected});

  final PocoConfigMode? selectedMode;
  final ValueChanged<PocoConfigMode?> onSelected;

  // Mirror PocoConfigMode's wire values (auto / approve / smart_approve /
  // chat). Unknown is excluded from the picker entirely — selecting
  // "unknown" makes no semantic sense and would round-trip to the server
  // as a value nothing in the Go coordinator recognises.
  static const List<PocoConfigMode> _availableModes = [
    PocoConfigMode.auto,
    PocoConfigMode.approve,
    PocoConfigMode.smart_approve,
    PocoConfigMode.chat,
  ];

  String _modeLabel(BuildContext context, PocoConfigMode mode) {
    switch (mode) {
      case PocoConfigMode.auto:
        return 'AUTO';
      case PocoConfigMode.approve:
        return 'APPROVE';
      case PocoConfigMode.smart_approve:
        return 'SMART APPROVE';
      case PocoConfigMode.chat:
        return 'CHAT';
      case PocoConfigMode.unknown:
        return context.l10n.agentNone.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = selectedMode;
    return _SelectionField(
      label: context.l10n.agentConfigModeLabel,
      currentValue: mode == null
          ? context.l10n.agentConfigSelectMode.toUpperCase()
          : _modeLabel(context, mode),
      onTap: () async {
        final picked = await _showListDialog<PocoConfigMode>(
          context,
          title: context.l10n.agentConfigSelectMode,
          emptyLabel: context.l10n.agentConfigNoModes,
          items: _availableModes
              .map((m) => (id: m, label: _modeLabel(context, m)))
              .toList(),
          initialValue: selectedMode,
        );
        if (picked != null) onSelected(picked);
      },
    );
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.currentValue,
    required this.onTap,
  });

  final String label;
  final String currentValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BiosRow(
      label: label,
      value: currentValue,
      variant: BiosRowVariant.expand,
      onTap: onTap,
    );
  }
}

/// Generic single-select list picker rendered as a [TerminalDialog].
///
/// No design-system picker widget exists yet (grep confirmed before writing
/// this) — implement a simple list-picker inline.
Future<T?> _showListDialog<T extends Object>(
  BuildContext context, {
  required String title,
  required String emptyLabel,
  required List<({T id, String label})> items,
  required T? initialValue,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => TerminalDialog(
      title: title,
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: items.isEmpty
            ? Center(
                child: TerminalText(
                  emptyLabel,
                  alpha: 0.5,
                ),
              )
            : ListView(
                children: [
                  for (final item in items)
                    BiosRow(
                      label: item.label,
                      isSelected:
                          initialValue != null && initialValue == item.id,
                      onTap: () => Navigator.of(dialogContext).pop(item.id),
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
}
