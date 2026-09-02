import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class SummaryField extends StatelessWidget {
  const SummaryField({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalText.mini(label.toUpperCase(), alpha: 0.5),
        VSpace.x0_5,
        TerminalText(
          value.toUpperCase(),
          size: TerminalTextSize.base,
          weight: TerminalTextWeight.heavy,
        ),
      ],
    );
  }
}
