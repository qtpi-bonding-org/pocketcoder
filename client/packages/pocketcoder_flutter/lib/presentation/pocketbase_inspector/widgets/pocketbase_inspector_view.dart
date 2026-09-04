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
              _CountCard(
                  label: context.l10n.pocketbaseInspectorUsers,
                  value: stats.users),
              _CountCard(
                  label: context.l10n.pocketbaseInspectorChats,
                  value: stats.chats),
              _CountCard(
                  label: context.l10n.pocketbaseInspectorAgentProfiles,
                  value: stats.agentProfiles),
              _CountCard(
                  label: context.l10n.pocketbaseInspectorHarnesses,
                  value: stats.harnesses),
              _CountCard(
                  label: context.l10n.pocketbaseInspectorMcpServers,
                  value: stats.mcpServers),
              _CountCard(
                  label: context.l10n.pocketbaseInspectorSkills,
                  value: stats.skills),
            ],
          ),
          VSpace.x2,
          BiosSection(
            title: context.l10n.pocketbaseInspectorRecentChats,
            child: stats.recentChats.isEmpty
                ? _EmptyLabel(context.l10n.pocketbaseInspectorNoChatsYet)
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
        padding: EdgeInsets.symmetric(horizontal: AppSizes.space / 2, vertical: AppSizes.space / 4),
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
                chat.archived
                    ? context.l10n.pocketbaseInspectorChatArchivedTitle(
                        chat.title)
                    : chat.title,
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
