import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/ai/ai_config_cubit.dart';
import 'package:pocketcoder_flutter/application/ai/ai_config_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_list_tile.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';

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
    final colors = context.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: ScanlineWidget(
        child: SafeArea(
          child: BlocBuilder<AiConfigCubit, AiConfigState>(
            builder: (context, state) {
              return Padding(
                padding: EdgeInsets.all(AppSizes.space * 2),
                child: Column(
                  children: [
                    TerminalHeader(title: 'AGENT REGISTRY'),
                    VSpace.x2,
                    Expanded(
                      child: BiosFrame(
                        title: 'MODELS & PERSONAS',
                        child: state.isLoading
                            ? const Center(
                                child: TerminalLoadingIndicator(
                                label: 'SEARCHING...',
                              ))
                            : _buildAgentList(context, state),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: TerminalFooter(
        actions: [
          TerminalAction(
            label: 'ADD NEW',
            onTap: () {
              // TODO: Implement add
            },
          ),
          TerminalAction(
            label: 'BACK',
            onTap: () => context.pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentList(BuildContext context, AiConfigState state) {
    final colors = context.colorScheme;
    if (state.agents.isEmpty) {
      return Center(
        child: Text(
          'REGISTRY EMPTY.',
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.5),
            package: 'pocketcoder_flutter',
          ),
        ),
      );
    }

    return Column(
      children: [
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
        Text(
          'SELECT AGENT TO CONFIGURE',
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface.withValues(alpha: 0.5),
            fontSize: AppSizes.fontTiny,
            package: 'pocketcoder_flutter',
          ),
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
        title: 'AGENT: ${agent.name.toUpperCase()}',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TerminalTextField(
                controller: nameController,
                label: 'NAME',
              ),
              VSpace.x2,
              TerminalTextField(
                controller: descController,
                label: 'DESCRIPTION',
                maxLines: 2,
              ),
              VSpace.x2,
              _buildSelection(
                context: dialogContext,
                label: 'PROMPTS',
                currentValue: state.prompts.any((p) => p.id == selectedPromptId)
                    ? state.prompts
                        .firstWhere((p) => p.id == selectedPromptId)
                        .name
                    : 'NONE',
                onTap: () {
                  // TODO: Implement list picker
                },
              ),
              VSpace.x2,
              _buildSelection(
                context: dialogContext,
                label: 'MODELS',
                currentValue: state.models.any((m) => m.id == selectedModelId)
                    ? state.models
                        .firstWhere((m) => m.id == selectedModelId)
                        .name
                    : 'NONE SELECTED',
                onTap: () {
                  // TODO: Implement list picker
                },
              ),
              VSpace.x2,
              _buildSelection(
                context: dialogContext,
                label: 'PARAMETERS',
                currentValue: 'DEFAULT [TUNED]',
                onTap: () {
                  // TODO: Implement parameters tuning
                },
              ),
            ],
          ),
        ),
        actions: [
          TerminalButton(
            label: 'CANCEL',
            isPrimary: false,
            onTap: () => Navigator.pop(dialogContext),
          ),
          HSpace.x2,
          TerminalButton(
            label: 'SAVE',
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
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface,
            fontSize: AppSizes.fontTiny,
            package: 'pocketcoder_flutter',
          ),
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
                  child: Text(
                    currentValue.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface,
                      fontSize: AppSizes.fontSmall,
                      package: 'pocketcoder_flutter',
                    ),
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
