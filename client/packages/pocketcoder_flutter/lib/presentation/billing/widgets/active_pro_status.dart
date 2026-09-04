import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class ActiveProStatus extends StatelessWidget {
  const ActiveProStatus(
      {super.key, required this.onRestore, required this.onManageSubscription});

  final VoidCallback onRestore;
  final VoidCallback onManageSubscription;

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
      TerminalButton(
          label: context.l10n.proManageSubscription,
          onTap: onManageSubscription,
          isPrimary: false),
      VSpace.x1,
      TerminalButton(
          label: context.l10n.proRestore, onTap: onRestore, isPrimary: false),
    ]);
  }
}
