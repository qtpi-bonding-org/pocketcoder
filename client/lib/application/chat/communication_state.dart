import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/chat/chat_message.dart';
import '../../domain/chat/chat.dart';

part 'communication_state.freezed.dart';

@freezed
class CommunicationState with _$CommunicationState {
  const factory CommunicationState({
    @Default([]) List<ChatMessage> messages,
    @Default([]) List<Chat> chats,
    @Default(false) bool isLoading,
    @Default(false) bool isPocoThinking,

    // The "Hot Pipe" message that is currently being streamed.
    // This is ephemeral and constructed from deltas.
    ChatMessage? hotMessage,
    String? chatId,
    String? opencodeId,
    String? error,
  }) = _CommunicationState;
}
