import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class CountCard extends StatelessWidget {
  const CountCard({super.key, required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(AppSizes.space),
        decoration: BoxDecoration(
          border: Border.all(color: context.colorScheme.primary)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TerminalText(
              '$value',
              role: TextRole.value,
            ),
            TerminalText(
              label,
              role: TextRole.label,
            ),
          ]));
}
