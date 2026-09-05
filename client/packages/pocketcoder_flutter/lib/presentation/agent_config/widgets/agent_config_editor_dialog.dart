import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/agent_config/widgets/agent_config_option_picker.dart';
import 'package:pocketcoder_flutter/presentation/agent_config/widgets/is_default_toggle.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

class AgentConfigEditorDialog extends StatefulWidget {
  const AgentConfigEditorDialog({
    super.key,
    required this.existing,
    required this.prompts,
    required this.permissionModes,
    required this.onSave,
    this.onDelete,
  });

  final PocoConfig? existing;
  final List<Prompt> prompts;
  final List<PermissionMode> permissionModes;
  final void Function(PocoConfig updated) onSave;
  final VoidCallback? onDelete;

  @override
  State<AgentConfigEditorDialog> createState() =>
      AgentConfigEditorDialogState();
}

class AgentConfigEditorDialogState extends State<AgentConfigEditorDialog> {
  late final TextEditingController _nameController;
  String? _systemPromptId;
  String? _permissionModeId;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _systemPromptId = existing?.systemPrompt;
    _permissionModeId = existing?.permissionMode;
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
      systemPrompt: _systemPromptId,
      workspaceFolders: existing?.workspaceFolders,
      acpMcpServers: existing?.acpMcpServers,
      isDefault: _isDefault,
      permissionMode: _permissionModeId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return TerminalDialog(
      title: existing == null
          ? context.l10n.agentConfigTitle.toLowerCase()
          : context.l10n
              .agentConfigDialogTitle(existing.name)
              .toLowerCase(),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: AppSizes.pickerHeight,
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
              AgentConfigOptionPicker<Prompt>(
                items: widget.prompts,
                selectedId: _systemPromptId,
                label: context.l10n.agentConfigPromptLabel,
                selectTitle: context.l10n.agentConfigSelectPrompt,
                emptyLabel: context.l10n.agentConfigNoPrompts,
                itemId: (prompt) => prompt.id,
                itemLabel: (prompt) => prompt.name,
                itemBuilder: (_, prompt, selected) => DetailRow(
                  label: prompt.name,
                  isSelected: selected?.id == prompt.id,
                ),
                onSelected: (id) => setState(() => _systemPromptId = id),
              ),
              VSpace.x2,
              AgentConfigOptionPicker<PermissionMode>(
                items: widget.permissionModes,
                selectedId: _permissionModeId,
                label: context.l10n.agentConfigModeLabel,
                selectTitle: context.l10n.agentConfigSelectMode,
                emptyLabel: context.l10n.agentConfigNoModes,
                itemId: (mode) => mode.id,
                itemLabel: (mode) => mode.name,
                itemBuilder: (_, mode, selected) => DetailRow(
                  label: mode.name,
                  isSelected: selected?.id == mode.id,
                ),
                onSelected: (id) => setState(() => _permissionModeId = id),
              ),
              VSpace.x2,
              IsDefaultToggle(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              if (widget.onDelete case final onDelete?) ...[
                VSpace.x2,
                TerminalButton(
                  label: context.l10n.agentConfigDelete,
                  kind: ActionKind.neutral,
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
          kind: ActionKind.neutral,
          onTap: () => Navigator.of(context).pop(),
        ),
        TerminalButton(
          label: context.l10n.actionSave,
          onTap: _handleSave,
        ),
      ],
    );
  }
}
