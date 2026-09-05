import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

class ActiveProStatus extends StatelessWidget {
  const ActiveProStatus(
      {super.key,
      required this.onRestore,
      required this.onManageSubscription,
      this.onContinue});

  final VoidCallback onRestore;
  final VoidCallback onManageSubscription;

  /// Set only when this screen is a guided-setup step the user must clear
  /// to proceed. Null everywhere else (e.g. reached from settings).
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TerminalText(
        context.l10n.proActive,
        role: TextRole.label,
      ),
      VSpace.x2,
      TerminalText(context.l10n.proActiveBody, role: TextRole.body),
      VSpace.x3,
      if (onContinue case final onContinue?) ...[
        TerminalButton(
            label: context.l10n.proContinueSetup,
            onTap: onContinue,
            kind: ActionKind.primary),
        VSpace.x1,
      ],
      TerminalButton(
          label: context.l10n.proManageSubscription,
          onTap: onManageSubscription,
          kind: ActionKind.neutral),
      VSpace.x1,
      TerminalButton(
          label: context.l10n.proRestore,
          onTap: onRestore,
          kind: ActionKind.neutral),
    ]);
  }
}
