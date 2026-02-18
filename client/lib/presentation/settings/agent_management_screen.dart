import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/bootstrap.dart';
import '../../application/ai/ai_config_cubit.dart';
import '../../application/ai/ai_config_state.dart';
import '../../design_system/primitives/app_fonts.dart';
import '../../design_system/primitives/app_palette.dart';
import '../../design_system/primitives/app_sizes.dart';
import '../../design_system/primitives/spacers.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import 'settings_screen.dart'; // For BiosFrame

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
    return Scaffold(
      backgroundColor: AppPalette.primary.backgroundPrimary,
      body: ScanlineWidget(
        child: SafeArea(
          child: BlocBuilder<AiConfigCubit, AiConfigState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return Center(
                child: BiosFrame(
                  title: 'AI REGISTRY MANAGER',
                  child: SizedBox(
                    width: 600,
                    height: 500,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'REGISTRY ACTIVE - Personas Found: ${state.agents.length}',
                          style: TextStyle(
                            fontFamily: AppFonts.bodyFamily,
                            color: AppPalette.primary.textPrimary,
                            fontSize: AppSizes.fontMini,
                          ),
                        ),
                        VSpace.x2,
                        Expanded(
                          child: ListView.builder(
                            itemCount: state.agents.length,
                            itemBuilder: (context, index) {
                              final agent = state.agents[index];
                              return _AgentListTile(
                                agent: agent,
                                onTap: () =>
                                    _showEditAgentDialog(context, agent, state),
                              );
                            },
                          ),
                        ),
                        VSpace.x2,
                        _buildFooterAction(context),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: TerminalFooter(
        actions: [
          TerminalAction(
            keyLabel: 'ESC',
            label: 'BACK',
            onTap: () => context.pop(),
          ),
          TerminalAction(
            keyLabel: 'F2',
            label: 'ADD NEW',
            onTap: () {
              // TODO: Implementation for adding agents
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooterAction(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.space),
      color: AppPalette.primary.textPrimary.withValues(alpha: 0.1),
      child: Text(
        'TAP AGENT TO EDIT IDENTITY',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.bodyFamily,
          color: AppPalette.primary.textPrimary,
          fontSize: AppSizes.fontMini,
          fontWeight: AppFonts.heavy,
        ),
      ),
    );
  }

  void _showEditAgentDialog(
      BuildContext context, dynamic agent, AiConfigState state) {
    final nameController = TextEditingController(text: agent.name);
    final descController = TextEditingController(text: agent.description);
    String selectedPromptId = agent.prompt; // Assuming foreign key
    String selectedModelId = agent.model ?? '';

    // If expand was used, these might be objects, but we need IDs for save.
    // The model currently stores String IDs for these fields as per Freezed definition.
    // However, if we added expand(), the JSON parsing needs to handle it.
    // Let's assume for now the ID is preserved in the base field or we can get it.

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('EDIT IDENTIY: ${agent.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Agent Name'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: state.prompts.any((p) => p.id == selectedPromptId)
                    ? selectedPromptId
                    : null,
                items: state.prompts
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) => selectedPromptId = val!,
                decoration: const InputDecoration(labelText: 'System Prompt'),
                isExpanded: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: state.models.any((m) => m.id == selectedModelId)
                    ? selectedModelId
                    : null,
                items: state.models
                    .map((m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) => selectedModelId = val!,
                decoration: const InputDecoration(labelText: 'AI Model'),
                isExpanded: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  selectedPromptId.isNotEmpty) {
                final updatedAgent = agent.copyWith(
                  name: nameController.text,
                  description: descController.text,
                  prompt: selectedPromptId,
                  model: selectedModelId.isEmpty ? null : selectedModelId,
                  // Steps, config, etc preserved by copyWith
                );
                context.read<AiConfigCubit>().saveAgent(updatedAgent);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save Identity'),
          ),
        ],
      ),
    );
  }
}

class _AgentListTile extends StatelessWidget {
  final dynamic agent; // AiAgent
  final VoidCallback? onTap;

  const _AgentListTile({required this.agent, this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderColor = AppPalette.primary.textPrimary;
    final isInit = agent.isInit ?? false;

    return Container(
      margin: EdgeInsets.symmetric(vertical: AppSizes.space * 0.25),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                color: isInit
                    ? Colors.blue
                    : Colors.amber, // Init (Poco) vs Workspace (CAO)
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
                        color: AppPalette.primary.textPrimary,
                        fontSize: AppSizes.fontStandard,
                        fontWeight: AppFonts.heavy,
                      ),
                    ),
                    Text(
                      isInit ? '[INIT ORCHESTRATOR]' : '[WORKSPACE WORKER]',
                      style: TextStyle(
                        fontFamily: AppFonts.bodyFamily,
                        color: AppPalette.primary.textPrimary
                            .withValues(alpha: 0.6),
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
