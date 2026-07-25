import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';

part 'chat_list_state.freezed.dart';

@freezed
sealed class ChatListState with _$ChatListState implements IUiFlowState {
  const ChatListState._();

  const factory ChatListState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<Chat> chats,
    String? lastCreatedChatId,
    Object? error,
  }) = _ChatListState;

  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get hasError => error != null;
}
