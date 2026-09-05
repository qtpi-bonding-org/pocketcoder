import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// `^C` is SIGINT, the keystroke that stops a running process. It carries no
/// angle brackets: those mark a discrete choice a modal is offering, and this
/// is the terminal's own control character.
class InterruptRow extends StatelessWidget {
  const InterruptRow({super.key, required this.onInterrupt});

  final VoidCallback onInterrupt;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onInterrupt,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.space * 2, vertical: AppSizes.space * 0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TerminalText('^C', role: TextRole.fail),
              HSpace.x1,
              TerminalText(context.l10n.chatInterruptHint,
                  role: TextRole.label),
            ],
          ),
        ),
      );
}
