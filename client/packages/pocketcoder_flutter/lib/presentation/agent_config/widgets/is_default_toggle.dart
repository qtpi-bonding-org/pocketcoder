import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_checkbox.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class IsDefaultToggle extends StatelessWidget {
  const IsDefaultToggle(
      {super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Row(children: [
      TerminalCheckbox(value: value, onChanged: onChanged),
      HSpace.x2,
      Expanded(
          child: TerminalText(
        context.l10n.agentConfigIsDefaultLabel,
        role: TextRole.body,
      )),
    ]);
  }
}
