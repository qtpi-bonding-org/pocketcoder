import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/chat/chat_message.dart';

part 'chat_state.freezed.dart';

@freezed
class ChatState with _$ChatState {
  const factory ChatState({
    @Default([]) List<ChatMessage> messages,
    @Default(false) bool isLoading,
    @Default(false) bool isPocoThinking,

    // The "Hot Pipe" message that is currently being streamed.
    // This is ephemeral and constructed from deltas.
    ChatMessage? hotMessage,
    String? chatId,
    String? error,
  }) = _ChatState;
}
