import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

void showAddRuleDialog(
  BuildContext context,
  Future<void> Function(String tool, String action) onCreateRule,
) {
  final toolController = TextEditingController();
  String selectedAction = 'allow';

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setState) => TerminalDialog(
        title: context.l10n.toolPermissionsAddRuleTitle,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalTextField(
              controller: toolController,
              label: context.l10n.toolPermissionsToolNameLabel,
              obscureText: false,
            ),
            VSpace.x2,
            Row(
              children: [
                ('allow', context.l10n.toolPermissionsAllowLabel),
                ('ask', context.l10n.toolPermissionsAskLabel),
                ('deny', context.l10n.toolPermissionsDenyLabel),
              ].map((entry) {
                final (value, label) = entry;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.space / 2),
                    child: TerminalButton(
                      label: label,
                      isPrimary: selectedAction == value,
                      onTap: () => setState(() => selectedAction = value),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TerminalDialogActions(
            confirmLabel: context.l10n.actionAdd,
            onConfirm: () {
              final tool = toolController.text.trim();
              if (tool.isEmpty) return;
              onCreateRule(tool, selectedAction);
              Navigator.of(dialogContext).pop();
            },
            cancelLabel: context.l10n.actionCancel,
            onCancel: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    ),
  );
}
