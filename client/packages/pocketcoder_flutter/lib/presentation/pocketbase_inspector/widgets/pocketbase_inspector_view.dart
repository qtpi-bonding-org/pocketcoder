import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/pocketbase_inspector/i_pocketbase_inspector_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class PocketbaseInspectorView extends StatelessWidget {
  const PocketbaseInspectorView({super.key, required this.stats});

  final PocketbaseInspectorStats stats;

  @override
  Widget build(BuildContext context) => ListView(children: [
        SectionHeader(name: 'pocketbase'),
        DetailRow(
          label: context.l10n.pocketbaseInspectorUsers.toLowerCase(),
          value: '${stats.users}',
        ),
        DetailRow(
          label: context.l10n.pocketbaseInspectorChats.toLowerCase(),
          value: '${stats.chats}',
        ),
        DetailRow(
          label: context.l10n.pocketbaseInspectorAgentProfiles.toLowerCase(),
          value: '${stats.agentProfiles}',
        ),
        DetailRow(
          label: context.l10n.pocketbaseInspectorHarnesses.toLowerCase(),
          value: '${stats.harnesses}',
        ),
        DetailRow(
          label: context.l10n.pocketbaseInspectorMcpServers.toLowerCase(),
          value: '${stats.mcpServers}',
        ),
        DetailRow(
          label: context.l10n.pocketbaseInspectorSkills.toLowerCase(),
          value: '${stats.skills}',
        ),
        VSpace.x2,
        SectionHeader(
            name: context.l10n.pocketbaseInspectorRecentChats.toLowerCase()),
        stats.recentChats.isEmpty
            ? _EmptyLabel(context.l10n.pocketbaseInspectorNoChatsYet)
            : Column(
                children: stats.recentChats
                    .map((chat) => _ChatRow(chat: chat))
                    .toList()),
      ]);
}

class _EmptyLabel extends StatelessWidget {
  const _EmptyLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space),
        child: TerminalText(
          label,
          role: TextRole.body,
        ),
      );
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat});

  final PocketbaseChatSummary chat;

  @override
  Widget build(BuildContext context) => DetailRow(
        label: chat.archived
            ? context.l10n
                .pocketbaseInspectorChatArchivedTitle(chat.title)
            : chat.title,
        value: _formatTime(chat.lastActive),
      );
}

String _formatTime(String timestampStr) {
  try {
    final dateTime = DateTime.parse(timestampStr);
    final now = DateTime.now();
    final isToday = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    if (isToday) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  } catch (e) {
    return timestampStr;
  }
}
