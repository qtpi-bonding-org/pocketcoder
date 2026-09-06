import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';
import 'skill_card.dart';

class SkillsViewData {
  const SkillsViewData(
      {this.skills = const [], this.isLoading = false, this.error});

  final List<Skill> skills;
  final bool isLoading;
  final Object? error;
}

class SkillsView extends StatelessWidget {
  const SkillsView(
      {super.key,
      required this.data,
      required this.onAdd,
      required this.onEdit,
      required this.onDelete});

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
        footer: buildPillarFooter(context, NavPillar.config),
        showBack: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(name: context.l10n.skillsRegistryTitle.toLowerCase()),
            Expanded(child: _buildBody(context, colors, global, project)),
          ],
        ));
  }

  Widget _buildBody(BuildContext context, ColorScheme colors,
      List<Skill> global, List<Skill> project) {
    if (data.isLoading) {
      return const Center(child: TerminalSpinner());
    }
    if (data.error != null) {
      return Center(
          child:
              TerminalText(safeErrorMessage(data.error), role: TextRole.warn));
    }

    return ListView(children: [
      Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child: TerminalButton(
              label: context.l10n.skillsAddButton, onTap: onAdd)),
      if (global.isNotEmpty) ...[
        SectionHeader(name: context.l10n.skillsGlobalSection.toLowerCase()),
        Column(
            children: global
                .map((skill) =>
                    SkillCard(skill: skill, onEdit: onEdit, onDelete: onDelete))
                .toList()),
      ],
      if (project.isNotEmpty) ...[
        SectionHeader(name: context.l10n.skillsProjectSection.toLowerCase()),
        Column(
            children: project
                .map((skill) =>
                    SkillCard(skill: skill, onEdit: onEdit, onDelete: onDelete))
                .toList()),
      ],
      if (data.skills.isEmpty)
        Center(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.space * 4),
            child: TerminalText(
              context.l10n.skillsNoSkills,
              role: TextRole.body,
            ),
          ),
        ),
    ]);
  }

  bool _isGlobal(Skill skill) {
    final metadata = skill.metadata;
    return metadata is! Map || '${metadata['projectDir'] ?? ''}'.isEmpty;
  }
}
