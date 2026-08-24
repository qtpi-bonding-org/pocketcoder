import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';

class SkillsViewData {
  const SkillsViewData({
    this.skills = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Skill> skills;
  final bool isLoading;
  final String? error;
}

class SkillsView extends StatelessWidget {
  const SkillsView({
    super.key,
    required this.data,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final SkillsViewData data;
  final VoidCallback onAdd;
  final ValueChanged<Skill> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final global = data.skills.where(_isGlobal).toList();
    final project = data.skills.where((skill) => !_isGlobal(skill)).toList();

    return PocketCoderShell(
      title: context.l10n.skillsTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.skillsRegistryTitle,
        child: _buildBody(context, colors, global, project),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme colors,
    List<Skill> global,
    List<Skill> project,
  ) {
    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data.error != null) {
      return Center(
        child: Text(context.l10n.homeErrorPrefix(data.error.toString()),
            style: TextStyle(color: context.terminalColors.warning)),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child:
              TerminalButton(label: context.l10n.skillsAddButton, onTap: onAdd),
        ),
        if (global.isNotEmpty)
          BiosSection(
            title: context.l10n.skillsGlobalSection,
            child: Column(
                children:
                    global.map((skill) => _skillItem(context, skill)).toList()),
          ),
        if (project.isNotEmpty)
          BiosSection(
            title: context.l10n.skillsProjectSection,
            child: Column(
                children: project
                    .map((skill) => _skillItem(context, skill))
                    .toList()),
          ),
        if (data.skills.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.space * 4),
              child: TerminalText(context.l10n.skillsNoSkills, alpha: 0.5),
            ),
          ),
      ],
    );
  }

  Widget _skillItem(BuildContext context, Skill skill) {
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

  bool _isGlobal(Skill skill) {
    final metadata = skill.metadata;
    return metadata is! Map || '${metadata['projectDir'] ?? ''}'.isEmpty;
  }
}
