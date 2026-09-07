import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

class PermissionModeEditorDialog extends StatefulWidget {
  const PermissionModeEditorDialog({
    super.key,
    required this.initialName,
    this.initialDescription,
    required this.onSubmit,
  });

  final String initialName;
  final String? initialDescription;
  final void Function(String name, String description) onSubmit;

  @override
  State<PermissionModeEditorDialog> createState() =>
      _PermissionModeEditorDialogState();
}

class _PermissionModeEditorDialogState
    extends State<PermissionModeEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _description = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TerminalDialog(
      title: context.l10n.permissionModesEditorTitle.toLowerCase(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalTextField(
              controller: _name,
              label: context.l10n.permissionModesNameLabel),
          VSpace.x2,
          TerminalTextField(
              controller: _description,
              label: context.l10n.permissionModesDescriptionLabel),
        ],
      ),
      actions: [
        TerminalDialogActions(actions: [
          TerminalActionSpec(context.l10n.actionCancel, ActionKind.refusal,
              () => Navigator.of(context).pop()),
          TerminalActionSpec(context.l10n.actionSave, ActionKind.primary, () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            widget.onSubmit(name, _description.text.trim());
            Navigator.of(context).pop();
          }),
        ]),
      ],
    );
  }
}
