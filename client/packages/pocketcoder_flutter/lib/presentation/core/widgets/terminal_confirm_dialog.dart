import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';

/// Screens needing stateful dialog content (a checkbox, etc.) should build
/// their own [TerminalDialog] directly instead.
Future<bool?> showTerminalConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String cancelLabel,
  required String confirmLabel,
  bool danger = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => TerminalDialog(
      title: title.toLowerCase(),
      content: Text(body),
      actions: [
        TerminalButton(
          label: cancelLabel,
          kind: ActionKind.refusal,
          onTap: () => Navigator.of(dialogContext).pop(false),
        ),
        TerminalButton(
          label: confirmLabel,
          kind: danger ? ActionKind.destructive : ActionKind.primary,
          onTap: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
}
