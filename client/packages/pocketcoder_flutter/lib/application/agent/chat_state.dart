import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/agent/conversation.dart';

part 'chat_state.freezed.dart';

enum AgentChatOperation {
  open,
  sendPrompt,
  cancel,
}

@freezed
class ChatState with _$ChatState implements IUiFlowState {
  const ChatState._();

  const factory ChatState({
    String? chatId,
    @Default(Conversation.empty) Conversation conversation,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    AgentChatOperation? lastOperation,
  }) = _ChatState;

  @override
  bool get isLoading => status == UiFlowStatus.loading;

  @override
  bool get isSuccess => status == UiFlowStatus.success;

  @override
  bool get isFailure => status == UiFlowStatus.failure;

  @override
  bool get isIdle => status == UiFlowStatus.idle;

  @override
  bool get hasError => error != null;
}
