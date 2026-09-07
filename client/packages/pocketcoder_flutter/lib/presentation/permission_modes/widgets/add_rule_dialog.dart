import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

void showAddRuleDialog(BuildContext context,
    Future<void> Function(String tool, String action) onCreateRule) {
  final toolController = TextEditingController();
  String selectedAction = 'allow';
  showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (dialogContext, setState) => TerminalDialog(
                title: context.l10n.toolPermissionsAddRuleTitle.toLowerCase(),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TerminalTextField(
                          controller: toolController,
                          label: context.l10n.toolPermissionsToolNameLabel),
                      VSpace.x2,
                      Row(
                          children: [
                        ('allow', context.l10n.toolPermissionsAllowLabel),
                        ('ask', context.l10n.toolPermissionsAskLabel),
                        ('deny', context.l10n.toolPermissionsDenyLabel)
                      ]
                              .map((entry) => Expanded(
                                      child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: AppSizes.space / 2),
                                    child: TerminalButton(
                                        label: entry.$2,
                                        kind: selectedAction == entry.$1
                                            ? ActionKind.primary
                                            : ActionKind.neutral,
                                        onTap: () => setState(
                                            () => selectedAction = entry.$1)),
                                  )))
                              .toList()),
                    ]),
                actions: [
                  TerminalDialogActions(actions: [
                    TerminalActionSpec(
                        context.l10n.actionCancel,
                        ActionKind.refusal,
                        () => Navigator.of(dialogContext).pop()),
                    TerminalActionSpec(
                        context.l10n.actionAdd, ActionKind.primary, () {
                      final tool = toolController.text.trim();
                      if (tool.isEmpty) return;
                      onCreateRule(tool, selectedAction);
                      Navigator.of(dialogContext).pop();
                    }),
                  ])
                ],
              )));
}
