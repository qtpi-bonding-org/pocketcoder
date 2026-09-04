import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

class SkillCard extends StatelessWidget {
  const SkillCard(
      {super.key,
      required this.skill,
      required this.onEdit,
      required this.onDelete});

  final Skill skill;
  final ValueChanged<Skill> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TerminalText(skill.name.toUpperCase(), role: TextRole.body),
      VSpace.x1,
      TerminalText(skill.description, role: TextRole.body),
      VSpace.x1,
      if (skill.isSystem ?? false)
        TerminalText(context.l10n.skillsBuiltInLabel, role: TextRole.body),
      if (!(skill.isSystem ?? false))
        Row(children: [
          Expanded(
              child: TerminalButton(
                  label: context.l10n.skillsEditButton,
                  kind: ActionKind.neutral,
                  onTap: () => onEdit(skill))),
          HSpace.x2,
          Expanded(
            child: TerminalButton(
                label: context.l10n.skillsDeleteButton,
                kind: ActionKind.refusal,
                onTap: () => onDelete(skill.id)),
          ),
        ]),
      VSpace.x2,
    ]);
  }
}
