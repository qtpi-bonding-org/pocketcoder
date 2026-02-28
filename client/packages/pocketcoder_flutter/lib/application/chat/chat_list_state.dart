import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';

part 'chat_list_state.freezed.dart';

@freezed
class ChatListState with _$ChatListState implements IUiFlowState {
  const factory ChatListState({
    @Default([]) List<Chat> chats,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
  }) = _ChatListState;

  const ChatListState._();

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
