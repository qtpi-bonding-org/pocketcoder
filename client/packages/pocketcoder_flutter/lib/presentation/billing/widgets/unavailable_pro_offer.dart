import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class UnavailableProOffer extends StatelessWidget {
  const UnavailableProOffer({super.key, required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalText.label(
          context.l10n.proUnavailable,
          color: context.terminalColors.warning,
        ),
        VSpace.x2,
        TerminalText(context.l10n.proUnavailableBody),
        VSpace.x3,
        TerminalButton(
          label: context.l10n.proRestore,
          onTap: onRestore,
          isPrimary: false,
        ),
      ],
    );
  }
}
