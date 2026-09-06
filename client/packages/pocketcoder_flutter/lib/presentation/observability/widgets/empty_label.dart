import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class EmptyLabel extends StatelessWidget {
  const EmptyLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space),
        child: TerminalText(
          label,
          role: TextRole.body,
        ),
      );
}
