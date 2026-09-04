import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';
import 'skill_card.dart';

class SkillsViewData {
  const SkillsViewData({
    this.skills = const [],
    this.isLoading = false,
    this.error});

  final List<Skill> skills;
  final bool isLoading;
  final Object? error;
}

class SkillsView extends StatelessWidget {
  const SkillsView({
    super.key,
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
      title: context.l10n.skillsTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.skillsRegistryTitle,
        child: _buildBody(context, colors, global, project)));
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme colors,
    List<Skill> global,
    List<Skill> project) {
    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data.error != null) {
      return Center(
        child: TerminalText(safeErrorMessage(data.error),
            role: TextRole.warn));
    }

    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child:
              TerminalButton(label: context.l10n.skillsAddButton, onTap: onAdd)),
        if (global.isNotEmpty)
          BiosSection(
            title: context.l10n.skillsGlobalSection,
            child: Column(
                children:
                    global
                        .map((skill) => SkillCard(
                              skill: skill,
                              onEdit: onEdit,
                              onDelete: onDelete))
                        .toList())),
        if (project.isNotEmpty)
          BiosSection(
            title: context.l10n.skillsProjectSection,
            child: Column(
                children: project
                    .map((skill) => SkillCard(
                          skill: skill,
                          onEdit: onEdit,
                          onDelete: onDelete))
                    .toList())),
        if (data.skills.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.space * 4),
              child: TerminalText(context.l10n.skillsNoSkills)), role: TextRole.body)
      ]);
  }

  bool _isGlobal(Skill skill) {
    final metadata = skill.metadata;
    return metadata is! Map || '${metadata['projectDir'] ?? ''}'.isEmpty;
  }
}
