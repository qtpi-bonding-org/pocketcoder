import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/interrupt_action.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_input.dart';

/// The chat prompt at the bottom of the terminal transcript.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.isLoading,
    required this.onSubmitted,
    this.focusNode,
    this.onInterrupt,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onSubmitted;
  final FocusNode? focusNode;

  /// Non-null only while a turn is running, which is what puts `^C` on the
  /// prompt line.
  final VoidCallback? onInterrupt;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: TerminalInput(
        controller: controller,
        focusNode: focusNode,
        prompt: context.l10n.chatComposerPrompt,
        enabled: enabled,
        onSubmitted: onSubmitted,
        trailing: switch (onInterrupt) {
          final onInterrupt? => InterruptAction(onInterrupt: onInterrupt),
          null => null,
        },
      ),
    );
  }
}
