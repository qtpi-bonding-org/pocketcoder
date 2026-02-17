import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import '../../application/chat/chat_cubit.dart';

class ChatMessageMapper implements IStateMessageMapper<ChatState> {
  @override
  MessageKey? map(ChatState state) {
    if (state.status.isSuccess && state.lastOperation != null) {
      return switch (state.lastOperation!) {
        ChatOperation.messageSent => const MessageKey.success('chat.messageSent'),
        ChatOperation.chatCreated => const MessageKey.success('chat.created'),
      };
    }
    return null;
  }
}