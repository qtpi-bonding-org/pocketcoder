import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/server_control/widgets/copy_button.dart';

void showAddUserDialog(
  BuildContext context,
  Future<void> Function(String email) onCreate,
) {
  final emailController = TextEditingController();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => TerminalDialog(
      title: context.l10n.usersAddDialogTitle.toLowerCase(),
      content: TerminalTextField(
        controller: emailController,
        label: context.l10n.usersEmailLabel,
        obscureText: false,
      ),
      actions: [
        TerminalDialogActions(actions: [
          TerminalActionSpec(context.l10n.actionCancel, ActionKind.refusal,
              () => Navigator.of(dialogContext).pop()),
          TerminalActionSpec(context.l10n.actionAdd, ActionKind.primary, () {
            final email = emailController.text.trim();
            if (email.isEmpty) return;
            Navigator.of(dialogContext).pop();
            onCreate(email);
          }),
        ]),
      ],
    ),
  );
}

void showRevealPasswordDialog(
  BuildContext context, {
  required String email,
  required String password,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => TerminalDialog(
      title: context.l10n.usersRevealDialogTitle.toLowerCase(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalText(context.l10n.usersRevealDialogBody(email),
              role: TextRole.body),
          VSpace.x2,
          TerminalText(password, role: TextRole.value),
          VSpace.x1,
          CopyButton(value: password),
        ],
      ),
      actions: [
        TerminalDialogActions(actions: [
          TerminalActionSpec(context.l10n.actionDone, ActionKind.primary,
              () => Navigator.of(dialogContext).pop()),
        ]),
      ],
    ),
  );
}
