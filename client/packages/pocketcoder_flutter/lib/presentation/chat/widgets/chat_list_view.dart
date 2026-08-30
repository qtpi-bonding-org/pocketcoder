import 'package:flutter/material.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_list_tile.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';

/// Pure chat-list rendering. State loading and navigation live in the adapter.
class ChatListView extends StatelessWidget {
  const ChatListView({
    super.key,
    required this.state,
    required this.onNewChat,
    required this.onOpen,
    required this.onArchive,
    required this.onDelete,
  });

  final ChatListState state;
  final VoidCallback onNewChat;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onArchive;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.navChats,
      activePillar: NavPillar.chats,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(AppSizes.space),
            child: TerminalButton(
              label: context.l10n.chatListNewChat,
              onTap: onNewChat,
            ),
          ),
          Expanded(
            child: state.status == UiFlowStatus.loading
                ? const Center(child: TerminalLoadingIndicator())
                : ListView.separated(
                    itemCount: state.chats.length,
                    separatorBuilder: (context, index) => Divider(
                      color: context.colorScheme.primary.withValues(alpha: 0.3),
                      thickness: AppSizes.borderWidth,
                      height: AppSizes.borderWidth,
                    ),
                    itemBuilder: (context, index) {
                      final chat = state.chats[index];
                      return ChatListTile(
                        chat: chat,
                        onOpen: onOpen,
                        onArchive: onArchive,
                        onDelete: onDelete,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
