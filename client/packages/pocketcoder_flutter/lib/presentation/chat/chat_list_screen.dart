import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

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
      child: UiFlowListener<ChatListCubit, ChatListState>(
        child: const ChatListView(),
      ),
    );
  }
}

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatListCubit, ChatListState>(
      listenWhen: (previous, current) =>
          previous.lastCreatedChatId != current.lastCreatedChatId &&
          current.lastCreatedChatId != null,
      listener: (context, state) {
        context.push('${AppRoutes.chat}/${state.lastCreatedChatId}');
      },
      builder: (context, state) {
        return PocketCoderShell(
          title: context.l10n.navChats,
          activePillar: NavPillar.chats,
          extraHeaderActions: [
            TerminalAction(
              label: context.l10n.chatListNewChat,
              onTap: () async {
                final cubit = context.read<ChatListCubit>();
                final selection = await showDialog<NewChatSelection>(
                  context: context,
                  builder: (_) => const NewChatDialog(),
                );
                if (selection == null) return;
                await cubit.createAndOpen(
                  title: selection.title,
                  harness: selection.harness,
                  harnessModelOverride: selection.harnessModelOverride,
                  ollamaModelOverride: selection.ollamaModelOverride,
                  workspaceOverride: selection.workspaceOverride,
                );
              },
            ),
          ],
          body: state.chats.isEmpty
              ? const Center(child: TerminalLoadingIndicator())
              : ListView.builder(
                  itemCount: state.chats.length,
                  itemBuilder: (context, index) {
                    final chat = state.chats[index];
                    return _ChatListTile(chat: chat);
                  },
                ),
        );
      },
    );
  }
}

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('${AppRoutes.chat}/${chat.id}'),
      onLongPress: () => _showActions(context, chat),
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

  void _showActions(BuildContext context, Chat chat) {
    final cubit = context.read<ChatListCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: chat.title,
        content: const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.archive(chat.id);
            },
            child: Text(context.l10n.chatListArchive),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.delete(chat.id);
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
