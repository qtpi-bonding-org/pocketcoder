import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/agent/chat_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/chat_state.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_state.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';

class ChatAdapter extends CubitAdapter<ChatCubit, ChatState> {
  const ChatAdapter({super.key, this.chatId});

  final String? chatId;

  static ChatState _selectState(ChatState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ChatCubit, ChatState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final chatCubit = context.read<ChatCubit>();
    final controls = context.read<SessionControlsCubit>();
    return UiFlowListener<ChatCubit, ChatState>(
      listener: (context, value) {
        if (value.error != null) {
          VimToast.show(context, '${value.error}', color: context.colorScheme.error);
        }
      },
      child: ValueListenableBuilder<ChatState>(
        valueListenable: state,
        builder: (context, value, _) => StreamBuilder<SessionControlsState>(
          stream: controls.stream,
          initialData: controls.state,
          builder: (context, controlsSnapshot) {
            final controlsValue = controlsSnapshot.data ?? controls.state;
            return ChatView(
              chatId: chatId,
              conversation: value.conversation,
              title: value.conversation.sessionState.title ?? context.l10n.chatSessionTitle,
              isLoading: value.isLoading,
              isRunning: value.isLoading || value.lastOperation == AgentChatOperation.sendPrompt,
              modes: controlsValue.modes,
              config: controlsValue.config,
              onOpen: (id) {
                chatCubit.open(id);
                context.read<PermissionCubit>().open(id);
                context.read<ElicitationCubit>().open(id);
                controls.open(id);
              },
              onSendPrompt: chatCubit.sendPrompt,
              onCancel: chatCubit.cancel,
              onSelectMode: controls.selectMode,
              onSetOption: controls.setOption,
              onPermissionOptionSelected: (requestId, {optionId, cancelled = false}) {
                final cubit = context.read<PermissionCubit>();
                if (cancelled || optionId == null) {
                  cubit.deny();
                } else {
                  cubit.authorize(optionId);
                }
              },
              onElicitationRespond: (_, __) {},
              onFiles: () => AppNavigation.toFiles(context),
            );
          },
        ),
      ),
    );
  }
}
