import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/bootstrap.dart';
import '../../application/ai/ai_config_cubit.dart';
import '../../application/ai/ai_config_state.dart';
import '../../design_system/theme/app_theme.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/terminal_dialog.dart';
import '../core/widgets/bios_frame.dart';

class AgentManagementScreen extends StatelessWidget {
  const AgentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AiConfigCubit>()..loadAll(),
      child: const AgentManagementView(),
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
                    _buildHeader(context),
                    VSpace.x2,
                    Expanded(
                      child: BiosFrame(
                        title: 'MODELS & PERSONAS',
                        child: state.isLoading
                            ? const Center(child: CircularProgressIndicator())
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
            keyLabel: 'F2',
            label: 'ADD NEW',
            onTap: () {
              // TODO: Implement add
            },
          ),
          TerminalAction(
            keyLabel: 'ESC',
            label: 'BACK',
            onTap: () => context.pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      children: [
        Text(
          'AI REGISTRY MANAGER',
          style: TextStyle(
            fontFamily: AppFonts.headerFamily,
            color: colors.onSurface,
            fontSize: AppSizes.fontBig,
            fontWeight: AppFonts.heavy,
            letterSpacing: 2,
          ),
        ),
        VSpace.x1,
        Container(
          height: AppSizes.borderWidth,
          color: colors.onSurface.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildAgentList(BuildContext context, AiConfigState state) {
    final colors = context.colorScheme;
    if (state.agents.isEmpty) {
      return Center(
        child: Text(
          'REGISTRY EMPTY.',
          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.5)),
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
              return _AgentListTile(
                agent: agent,
                onTap: () => _showEditAgentDialog(context, agent, state),
              );
            },
          ),
        ),
        VSpace.x2,
        Text(
          'TAP IDENTITY TO MODIFY PARAMS',
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface.withValues(alpha: 0.5),
            fontSize: AppSizes.fontTiny,
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
        title: 'IDENTITY: ${agent.name.toUpperCase()}',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTerminalTextField(
                context: dialogContext,
                controller: nameController,
                label: 'AGENT NAME',
              ),
              VSpace.x2,
              _buildTerminalTextField(
                context: dialogContext,
                controller: descController,
                label: 'DESCRIPTION',
                maxLines: 2,
              ),
              VSpace.x2,
              _buildSelection(
                context: dialogContext,
                label: 'SYSTEM PROMPT',
                currentValue: state.prompts.any((p) => p.id == selectedPromptId)
                    ? state.prompts
                        .firstWhere((p) => p.id == selectedPromptId)
                        .name
                    : 'NONE',
                onTap: () {
                  // TODO: Implement a terminal-style list picker
                },
              ),
              VSpace.x2,
              _buildSelection(
                context: dialogContext,
                label: 'AI MODEL',
                currentValue: state.models.any((m) => m.id == selectedModelId)
                    ? state.models
                        .firstWhere((m) => m.id == selectedModelId)
                        .name
                    : 'NONE SELECTED',
                onTap: () {
                  // TODO: Implement a terminal-style list picker
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

class _AgentListTile extends StatelessWidget {
  final dynamic agent;
  final VoidCallback? onTap;

  const _AgentListTile({required this.agent, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final borderColor = colors.onSurface;
    final isInit = agent.isInit ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.space),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
        color:
            isInit ? borderColor.withValues(alpha: 0.05) : Colors.transparent,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                color: isInit
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.4),
              ),
              HSpace.x2,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppFonts.bodyFamily,
                        color: colors.onSurface,
                        fontSize: AppSizes.fontStandard,
                        fontWeight: AppFonts.heavy,
                      ),
                    ),
                    Text(
                      isInit ? '>> INIT ORCHESTRATOR' : '>> WORKSPACE WORKER',
                      style: TextStyle(
                        fontFamily: AppFonts.bodyFamily,
                        color: colors.onSurface.withValues(alpha: 0.5),
                        fontSize: AppSizes.fontMini,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: borderColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildTerminalTextField({
  required BuildContext context,
  required TextEditingController controller,
  required String label,
  int maxLines = 1,
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
        ),
      ),
      VSpace.x1,
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          fontFamily: AppFonts.bodyFamily,
          color: colors.onSurface,
          fontSize: AppSizes.fontSmall,
        ),
        cursorColor: colors.onSurface,
        decoration: const InputDecoration(), // Uses theme decoration
      ),
    ],
  );
}
