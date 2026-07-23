import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/application/skills/skills_cubit.dart';
import 'package:pocketcoder_flutter/application/skills/skills_state.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/domain/agent_config/i_agent_config_repository.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<SkillsCubit>()..loadSkills(),
      child: UiFlowListener<SkillsCubit, SkillsState>(
        child: const _SkillsView(),
      ),
    );
  }
}

class _SkillsView extends StatelessWidget {
  const _SkillsView();

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.skillsTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.skillsRegistryTitle,
        child: BlocBuilder<SkillsCubit, SkillsState>(
          builder: (context, state) {
            final colors = context.colorScheme;
            return state.maybeWhen(
              loaded: (skills) {
                final global =
                    skills.where((s) => s.global).toList();
                final project =
                    skills.where((s) => !s.global).toList();

                return ListView(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(AppSizes.space),
                      child: TerminalButton(
                        label: context.l10n.skillsAddButton,
                        onTap: () => _showAddSkillDialog(context),
                      ),
                    ),
                    if (global.isNotEmpty)
                      BiosSection(
                        title: context.l10n.skillsGlobalSection,
                        child: Column(
                          children: global
                              .map((s) => _buildSkillItem(context, s))
                              .toList(),
                        ),
                      ),
                    if (project.isNotEmpty)
                      BiosSection(
                        title: context.l10n.skillsProjectSection,
                        child: Column(
                          children: project
                              .map((s) => _buildSkillItem(context, s))
                              .toList(),
                        ),
                      ),
                    if (skills.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSizes.space * 4),
                          child: TerminalText(
                            context.l10n.skillsNoSkills,
                            alpha: 0.5,
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (msg) => Center(
                child: Text(
                  'ERROR: $msg',
                  style: TextStyle(color: colors.error),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkillItem(BuildContext context, Skill skill) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TerminalText(
            skill.name.toUpperCase(),
            weight: TerminalTextWeight.heavy,
          ),
          VSpace.x1,
          TerminalText.mini(skill.description, alpha: 0.6),
          VSpace.x1,
          Row(
            children: [
              Expanded(
                child: TerminalButton(
                  label: context.l10n.skillsEditButton,
                  isPrimary: false,
                  onTap: () => _showEditSkillDialog(context, skill),
                ),
              ),
              HSpace.x2,
              TerminalButton(
                label: context.l10n.skillsDeleteButton,
                color: context.colorScheme.error,
                onTap: () =>
                    context.read<SkillsCubit>().deleteSkill(skill.path),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditSkillDialog(BuildContext context, Skill skill) {
    final colors = Theme.of(context).colorScheme;
    final cubit = context.read<SkillsCubit>();
    final nameController = TextEditingController(text: skill.name);
    final descriptionController =
        TextEditingController(text: skill.description);
    final contentController = TextEditingController(text: skill.content);

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.skillsEditDialogTitle(skill.name.toUpperCase()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalTextField(
              controller: nameController,
              label: context.l10n.skillsNameLabel,
              obscureText: false,
            ),
            VSpace.x2,
            TerminalTextField(
              controller: descriptionController,
              label: context.l10n.skillsDescriptionLabel,
              obscureText: false,
            ),
            VSpace.x2,
            TerminalTextField(
              controller: contentController,
              label: context.l10n.skillsContentLabel,
              obscureText: false,
              maxLines: 8,
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurface,
              side: BorderSide(
                  color: colors.onSurface.withValues(alpha: 0.3)),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.actionCancel),
          ),
          HSpace.x2,
          OutlinedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();
              final content = contentController.text.trim();
              if (name.isEmpty || description.isEmpty || content.isEmpty) {
                return;
              }
              cubit.updateSkill(
                path: skill.path,
                name: name,
                description: description,
                content: content,
              );
              Navigator.of(dialogContext).pop();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.skillsSaveButton),
          ),
        ],
      ),
    );
  }

  void _showAddSkillDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cubit = context.read<SkillsCubit>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StreamBuilder<List<PocoConfig>>(
        stream: getIt<IAgentConfigRepository>().watchConfigs(),
        builder: (context, snapshot) {
          bool isGlobal = true;
          PocoConfig? selectedConfig;

          final eligibleConfigs = (snapshot.data ?? [])
              .where((c) =>
                  (c.workspaceFolders is List) &&
                  (c.workspaceFolders as List).isNotEmpty)
              .toList();

          return StatefulBuilder(
            builder: (dialogContext, setState) => TerminalDialog(
              title: context.l10n.skillsAddDialogTitle,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TerminalTextField(
                    controller: nameController,
                    label: context.l10n.skillsNameLabel,
                    obscureText: false,
                  ),
                  VSpace.x2,
                  TerminalTextField(
                    controller: descriptionController,
                    label: context.l10n.skillsDescriptionLabel,
                    obscureText: false,
                  ),
                  VSpace.x2,
                  TerminalTextField(
                    controller: contentController,
                    label: context.l10n.skillsContentLabel,
                    obscureText: false,
                    maxLines: 8,
                  ),
                  VSpace.x2,
                  Row(
                    children: [
                      Expanded(
                        child: TerminalButton(
                          label: context.l10n.skillsGlobalLabel,
                          isPrimary: isGlobal,
                          onTap: () => setState(() {
                            isGlobal = true;
                            selectedConfig = null;
                          }),
                        ),
                      ),
                      HSpace.x2,
                      Expanded(
                        child: TerminalButton(
                          label: context.l10n.skillsProjectLabel,
                          isPrimary: !isGlobal,
                          onTap: eligibleConfigs.isEmpty
                              ? () {}
                              : () => setState(() {
                                    isGlobal = false;
                                    selectedConfig ??= eligibleConfigs.first;
                                  }),
                        ),
                      ),
                    ],
                  ),
                  if (!isGlobal && eligibleConfigs.isEmpty) ...[
                    VSpace.x1,
                    TerminalText.mini(
                      context.l10n.skillsNoEligibleConfig,
                      alpha: 0.6,
                    ),
                  ],
                  if (!isGlobal && eligibleConfigs.isNotEmpty) ...[
                    VSpace.x1,
                    DropdownButton<PocoConfig>(
                      isExpanded: true,
                      value: eligibleConfigs.contains(selectedConfig)
                          ? selectedConfig
                          : null,
                      items: eligibleConfigs
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (c) =>
                          setState(() => selectedConfig = c),
                    ),
                  ],
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onSurface,
                    side: BorderSide(
                        color: colors.onSurface.withValues(alpha: 0.3)),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: Text(context.l10n.actionCancel),
                ),
                HSpace.x2,
                OutlinedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final description = descriptionController.text.trim();
                    final content = contentController.text.trim();
                    if (name.isEmpty ||
                        description.isEmpty ||
                        content.isEmpty) {
                      return;
                    }
                    String? projectDir;
                    if (!isGlobal) {
                      final config = selectedConfig;
                      if (config == null) return;
                      final folders = config.workspaceFolders;
                      if (folders is! List || folders.isEmpty) return;
                      projectDir = folders.first as String;
                    }
                    cubit.createSkill(
                      name: name,
                      description: description,
                      content: content,
                      global: isGlobal,
                      projectDir: projectDir,
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: Text(context.l10n.actionAdd),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
