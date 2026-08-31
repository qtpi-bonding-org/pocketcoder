import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/pocketbase_inspector/pocketbase_inspector_cubit.dart';
import 'package:pocketcoder_flutter/application/pocketbase_inspector/pocketbase_inspector_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/pocketbase_inspector/i_pocketbase_inspector_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';

class PocketbaseInspectorScreen extends StatefulWidget {
  const PocketbaseInspectorScreen({super.key});

  @override
  State<PocketbaseInspectorScreen> createState() =>
      _PocketbaseInspectorScreenState();
}

class _PocketbaseInspectorScreenState
    extends State<PocketbaseInspectorScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PocketbaseInspectorCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PocketbaseInspectorCubit, PocketbaseInspectorState>(
        builder: (context, state) => PocketCoderShell(
          title: 'POCKETBASE',
          activePillar: NavPillar.configure,
          showBack: true,
          body: switch (state.status) {
            UiFlowStatus.loading ||
            UiFlowStatus.idle =>
              const Center(child: TerminalLoadingIndicator()),
            UiFlowStatus.failure => Center(
                child: Text(
                  'DATABASE UNAVAILABLE',
                  style: TextStyle(color: context.terminalColors.warning),
                ),
              ),
            UiFlowStatus.success => _PocketbaseContent(
                stats: state.stats ?? const PocketbaseInspectorStats(),
              ),
          },
        ),
      );
}

class _PocketbaseContent extends StatelessWidget {
  const _PocketbaseContent({required this.stats});

  final PocketbaseInspectorStats stats;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: AppSizes.space,
            crossAxisSpacing: AppSizes.space,
            childAspectRatio: 1.4,
            children: [
              _CountCard(label: 'USERS', value: stats.users),
              _CountCard(label: 'CHATS', value: stats.chats),
              _CountCard(label: 'AGENT PROFILES', value: stats.agentProfiles),
              _CountCard(label: 'HARNESSES', value: stats.harnesses),
              _CountCard(label: 'MCP SERVERS', value: stats.mcpServers),
              _CountCard(label: 'SKILLS', value: stats.skills),
            ],
          ),
          VSpace.x2,
          BiosSection(
            title: 'Recent Chats',
            child: stats.recentChats.isEmpty
                ? const _EmptyLabel('No chats yet')
                : Column(
                    children: stats.recentChats
                        .map((chat) => _ChatRow(chat: chat))
                        .toList(),
                  ),
          ),
        ],
      );
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(AppSizes.space),
        decoration: BoxDecoration(
          border: Border.all(color: context.colorScheme.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: context.colorScheme.primary,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontLarge,
                fontWeight: AppFonts.heavy,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: context.colorScheme.onSurface,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
            ),
          ],
        ),
      );
}

class _EmptyLabel extends StatelessWidget {
  const _EmptyLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space),
        child: Text(
          label,
          style: TextStyle(
            color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontSmall,
          ),
        ),
      );
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat});

  final PocketbaseChatSummary chat;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: AppSizes.space),
        child: Row(
          children: [
            Expanded(
              child: Text(
                chat.archived ? '${chat.title} (archived)' : chat.title,
                style: TextStyle(
                  color: context.colorScheme.onSurface,
                  fontFamily: AppFonts.bodyFamily,
                ),
              ),
            ),
            Text(
              chat.lastActive,
              style: TextStyle(
                color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontSmall,
              ),
            ),
          ],
        ),
      );
}
