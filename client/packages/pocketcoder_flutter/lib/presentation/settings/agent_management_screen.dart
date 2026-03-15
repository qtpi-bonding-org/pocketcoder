import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/ai/ai_config_cubit.dart';
import 'package:pocketcoder_flutter/application/ai/ai_config_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_list_tile.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class AgentManagementScreen extends StatelessWidget {
  const AgentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AiConfigCubit>()..watchAll(),
      child: UiFlowListener<AiConfigCubit, AiConfigState>(
        child: const AgentManagementView(),
      ),
    );
  }
}

class AgentManagementView extends StatelessWidget {
  const AgentManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiConfigCubit, AiConfigState>(
      builder: (context, state) {
        return PocketCoderShell(
          title: context.l10n.agentTitle,
          activePillar: NavPillar.configure,
          showBack: true,
          body: BiosFrame(
            title: context.l10n.agentModelsPersonas,
            child: state.isLoading
                ? Center(
                    child: TerminalLoadingIndicator(
                    label: context.l10n.agentSearching,
                  ))
                : _buildAgentList(context, state),
          ),
        );
      },
    );
  }

  Widget _buildAgentList(BuildContext context, AiConfigState state) {
    final colors = context.colorScheme;
    if (state.agents.isEmpty) {
      return Center(
        child: Text(
          context.l10n.agentRegistryEmpty,
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.5),
            package: 'pocketcoder_flutter',
          ),
        ),
      );
    }

    return Column(
      children: [
        // Inline ADD NEW button
        Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child: TerminalButton(
            label: 'ADD NEW',
            onTap: () {
              // TODO: Implement add
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.agents.length,
            itemBuilder: (context, index) {
              final agent = state.agents[index];
              return BiosListTile(
                label: agent.name.toUpperCase(),
                value: (agent.isInit ?? false) ? 'INIT' : 'WORKER',
                onTap: () => _showEditAgentDialog(context, agent, state),
              );
            },
          ),
        ),
        VSpace.x2,
        TerminalText.tiny(
          context.l10n.agentSelectToConfigure,
          alpha: 0.5,
        ),
      ],
    );
  }

  void _showEditAgentDialog(
      BuildContext context, dynamic agent, AiConfigState state) {
    final nameController = TextEditingController(text: agent.name);
    final descController = TextEditingController(text: agent.description);
    String selectedPromptId = agent.prompt;
    String selectedModelId = agent.model ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.agentDialogTitle(agent.name.toUpperCase()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TerminalTextField(
                controller: nameController,
                label: context.l10n.agentNameLabel,
              ),
              VSpace.x2,
              TerminalTextField(
                controller: descController,
                label: context.l10n.agentDescriptionLabel,
                maxLines: 2,
              ),
              VSpace.x2,
              _buildSelection(
                context: dialogContext,
                label: context.l10n.agentPromptsLabel,
                currentValue: state.prompts.any((p) => p.id == selectedPromptId)
                    ? state.prompts
                        .firstWhere((p) => p.id == selectedPromptId)
                        .name
                    : context.l10n.agentNone,
                onTap: () {
                  // TODO: Implement list picker
                },
              ),
              VSpace.x2,
              _buildSelection(
                context: dialogContext,
                label: context.l10n.agentModelsLabel,
                currentValue: state.models.any((m) => m.id == selectedModelId)
                    ? state.models
                        .firstWhere((m) => m.id == selectedModelId)
                        .name
                    : context.l10n.agentNoneSelected,
                onTap: () {
                  // TODO: Implement list picker
                },
              ),
              VSpace.x2,
              _buildSelection(
                context: dialogContext,
                label: context.l10n.agentParametersLabel,
                currentValue: context.l10n.agentDefaultTuned,
                onTap: () {
                  // TODO: Implement parameters tuning
                },
              ),
            ],
          ),
        ),
        actions: [
          TerminalButton(
            label: context.l10n.actionCancel,
            isPrimary: false,
            onTap: () => Navigator.pop(dialogContext),
          ),
          HSpace.x2,
          TerminalButton(
            label: context.l10n.actionSave,
            onTap: () {
              if (nameController.text.isNotEmpty &&
                  selectedPromptId.isNotEmpty) {
                final updatedAgent = agent.copyWith(
                  name: nameController.text,
                  description: descController.text,
                  prompt: selectedPromptId,
                  model: selectedModelId.isEmpty ? null : selectedModelId,
                );
                context.read<AiConfigCubit>().saveAgent(updatedAgent);
                Navigator.pop(dialogContext);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelection({
    required BuildContext context,
    required String label,
    required String currentValue,
    required VoidCallback onTap,
  }) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TerminalText.tiny(
          label,
          color: colors.onSurface,
        ),
        VSpace.x1,
        InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(AppSizes.space),
            decoration: BoxDecoration(
              border:
                  Border.all(color: colors.onSurface.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TerminalText(
                    currentValue.toUpperCase(),
                    color: colors.onSurface,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: colors.onSurface),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
