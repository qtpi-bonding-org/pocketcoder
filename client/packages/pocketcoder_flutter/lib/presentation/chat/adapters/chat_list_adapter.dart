import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/presentation/chat/chat_list_screen.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

class ChatListAdapter extends CubitAdapter<ChatListCubit, ChatListState> {
  const ChatListAdapter({super.key});

  static ChatListState _selectState(ChatListState state) => state;
  static String? _selectCreatedChat(ChatListState state) => state.lastCreatedChatId;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ChatListCubit, ChatListState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final createdChat = adapter.cubitField(_selectCreatedChat);
    adapter.listenTo(#createdChat, createdChat, () {
      final id = createdChat.value;
      if (id != null && id.isNotEmpty && context.mounted) {
        context.push('${AppRoutes.chat}/$id');
      }
    });
    final cubit = context.read<ChatListCubit>();
    return UiFlowListener<ChatListCubit, ChatListState>(
      child: ValueListenableBuilder<ChatListState>(
        valueListenable: state,
        builder: (context, value, _) => ChatListView(
          state: value,
          onNewChat: () async {
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
          onOpen: (id) => context.push('${AppRoutes.chat}/$id'),
          onArchive: cubit.archive,
          onDelete: cubit.delete,
        ),
      ),
    );
  }
}
