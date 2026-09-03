import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/pocketbase_inspector/i_pocketbase_inspector_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class PocketbaseInspectorView extends StatelessWidget {
  const PocketbaseInspectorView({super.key, required this.stats});

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
            // The terminal shell caps its content width, so at larger display
            // scales each of these three columns can be only about 100 px
            // wide. A slightly taller card keeps the scaled count and label
            // within the padded content area.
            childAspectRatio: 1.15,
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
            TerminalText(
              '$value',
              size: TerminalTextSize.large,
              weight: TerminalTextWeight.heavy,
              color: context.colorScheme.primary,
            ),
            TerminalText.mini(
              label,
              color: context.colorScheme.onSurface,
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
        child: TerminalText(
          label,
          color: context.colorScheme.onSurface,
          alpha: 0.6,
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
              child: TerminalText(
                chat.archived ? '${chat.title} (archived)' : chat.title,
                color: context.colorScheme.onSurface,
              ),
            ),
            TerminalText(
              chat.lastActive,
              color: context.colorScheme.onSurface,
              alpha: 0.7,
            ),
          ],
        ),
      );
}
