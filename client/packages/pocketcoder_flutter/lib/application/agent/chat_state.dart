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
    // True while ChatCubit is auto-retrying a prompt after the harness
    // container reported not-ready-yet (a real, expected cold-start window
    // -- observed up to ~150s -- not an error). The view uses this to show
    // "starting the harness..." instead of a generic spinner/error toast.
    @Default(false) bool awaitingHarnessStart,
  }) = _ChatState;
}
