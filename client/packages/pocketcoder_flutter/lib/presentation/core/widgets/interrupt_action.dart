import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// `^C` is SIGINT, the keystroke that stops a running process. It carries no
/// angle brackets: those mark a discrete choice a modal is offering, and this
/// is the terminal's own control character. Amber, not red: stopping a turn
/// interrupts work, it does not destroy anything.
///
/// It sits in the prompt line rather than a row of its own, so the one place
/// a turn is started is the one place it is stopped.
class InterruptAction extends StatelessWidget {
  const InterruptAction({super.key, required this.onInterrupt});

  final VoidCallback onInterrupt;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onInterrupt,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
          child: TerminalText('^C', role: TextRole.warn),
        ),
      );
}
