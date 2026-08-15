import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_input.dart';

/// The chat prompt at the bottom of the terminal transcript.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.isLoading,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(AppSizes.space),
        child: TerminalInput(
          controller: controller,
          prompt: 'root@device \$',
          enabled: enabled,
          showSendButton: true,
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}
