import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import '../../domain/chat/chat_message.dart';
import '../../domain/chat/chat.dart';

part 'communication_state.freezed.dart';

enum ChatOperation {
  initialize,
  sendMessage,
  loadHistory,
}

@freezed
class CommunicationState with _$CommunicationState implements IUiFlowState {
  const CommunicationState._();

  const factory CommunicationState({
    @Default([]) List<ChatMessage> messages,
    @Default([]) List<Chat> chats,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default(false) bool isPocoThinking,
    ChatMessage? hotMessage,
    String? chatId,
    String? opencodeId,
    Object? error,
    ChatOperation? lastOperation,
  }) = _CommunicationState;

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
