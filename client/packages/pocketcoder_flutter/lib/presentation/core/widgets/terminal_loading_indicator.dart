import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class TerminalLoadingIndicator extends StatelessWidget {
  final String? label;

  const TerminalLoadingIndicator({
    super.key,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TerminalSpinner(),
        if (label != null && label!.isNotEmpty)
          TerminalText(label!, role: TextRole.body),
      ],
    );
  }
}
