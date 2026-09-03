import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';

class SkillCard extends StatelessWidget {
  const SkillCard({
    super.key,
    required this.skill,
    required this.onEdit,
    required this.onDelete,
  });

  final Skill skill;
  final ValueChanged<Skill> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TerminalText(skill.name.toUpperCase(),
              weight: TerminalTextWeight.heavy),
          VSpace.x1,
          TerminalText.mini(skill.description, alpha: 0.6),
          VSpace.x1,
          if (skill.isSystem ?? false)
            const TerminalText.mini('BUILT-IN', alpha: 0.5)
          else
            Row(
              children: [
                Expanded(
                  child: TerminalButton(
                    label: context.l10n.skillsEditButton,
                    isPrimary: false,
                    onTap: () => onEdit(skill),
                  ),
                ),
                HSpace.x2,
                Expanded(
                  child: TerminalButton(
                    label: context.l10n.skillsDeleteButton,
                    color: context.terminalColors.warning,
                    onTap: () => onDelete(skill.id),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
