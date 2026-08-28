import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'chat_state.freezed.dart';

enum AgentChatOperation {
  open,
  sendPrompt,
  cancel,
}

@freezed
sealed class ChatState with _$ChatState, UiFlowStateMixin {
  const ChatState._();

  const factory ChatState({
    String? chatId,
    @Default(Conversation.empty) Conversation conversation,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    AgentChatOperation? lastOperation,
    @Default(<String>{}) Set<String> animatedMessageIds,
  }) = _ChatState;
}
