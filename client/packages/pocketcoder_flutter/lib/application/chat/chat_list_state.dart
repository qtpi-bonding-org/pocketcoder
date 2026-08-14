import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';

part 'chat_list_state.freezed.dart';

@freezed
sealed class ChatListState with _$ChatListState, UiFlowStateMixin {
  const ChatListState._();

  const factory ChatListState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<Chat> chats,
    String? lastCreatedChatId,
    Object? error,
  }) = _ChatListState;

}
