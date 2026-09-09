import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// `↵` is the literal Return/Enter glyph -- no angle brackets, matching
/// [InterruptAction]'s `^C`: both stand for a real keystroke, not a
/// modal-offered choice.
///
/// Sits in the prompt line, the slot [InterruptAction] takes over once a turn
/// starts -- always exactly one tap target there, never both.
class SendAction extends StatelessWidget {
  const SendAction({super.key, required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSend,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
          child: TerminalText('↵', role: TextRole.value),
        ),
      );
}
