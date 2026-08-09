import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
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
    return BlocProvider(
      create: (_) => getIt<ChatListCubit>()
        ..watchChats()
        ..checkEmptyAndMaybeAutoCreate(),
      child: const ChatListAdapter(),
    );
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
                    return _ChatListTile(
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

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({
    required this.chat,
    required this.onOpen,
    required this.onArchive,
    required this.onDelete,
  });

  final Chat chat;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onArchive;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onOpen(chat.id),
      onLongPress: () => _showActions(context),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.space),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TerminalText.label(chat.title),
            TerminalText.mini(
              chat.preview ?? context.l10n.chatListNoMessages,
              alpha: 0.6,
            ),
            TerminalText.mini(
              _formatRelativeTime(chat.lastActive),
              alpha: 0.4,
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: chat.title,
        content: const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onArchive(chat.id);
            },
            child: Text(context.l10n.chatListArchive),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onDelete(chat.id);
            },
            child: Text(context.l10n.chatListDelete),
          ),
        ],
      ),
    );
  }
}

String _formatRelativeTime(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}
