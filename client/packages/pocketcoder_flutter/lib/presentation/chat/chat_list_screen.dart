import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_list_tile.dart';
import 'adapters/chat_list_adapter.dart';

/// Top-level screen for the chat-list landing pillar.
///
/// Provides the [ChatListCubit] via `BlocProvider(create: ...)`, cascading
/// both `watchChats()` (the live list) and `checkEmptyAndMaybeAutoCreate()`
/// (the one-shot, network-authoritative first-chat auto-create decision —
/// see `ChatListCubit`'s doc comment for why this is not driven by
/// `watchChats()`'s possibly cache-stale emissions). Mirrors
/// `AgentConfigScreen`/`ProviderScreen`'s screen/view split so widget tests
/// can pump [ChatListView] directly with a fake cubit.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatListScreenAdapter();
  }
}

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
      extraHeaderActions: [
        TerminalAction(
          label: context.l10n.chatListNewChat,
          onTap: onNewChat,
        ),
      ],
      body: state.chats.isEmpty
          ? const Center(child: TerminalLoadingIndicator())
          : ListView.builder(
              itemCount: state.chats.length,
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
    );
  }
}
