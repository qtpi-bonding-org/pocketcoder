import 'package:freezed_annotation/freezed_annotation.dart';
import '../chat/chat.dart';
import '../chat/chat_message.dart';

part 'i_communication_repository.freezed.dart';

abstract class ICommunicationRepository {
  /// Stream of finalized messages from the history (Cold Pipe)
  Stream<List<ChatMessage>> watchColdPipe(String chatId);

  /// Stream of ephemeral terminal events (Hot Pipe)
  Stream<HotPipeEvent> watchHotPipe();

  /// Sends a new user message to the chat
  Future<void> sendMessage(String chatId, String content);

  /// Ensures a chat exists with the given title and returns its ID
  Future<String> ensureChat(String title);

  /// Gets the OpenCode session ID for a chat
  Future<String?> getOpencodeId(String chatId);

  /// Watches a specific chat record for changes (e.g. opencode_id updates)
  Stream<Chat> watchChat(String chatId);

  /// Fetches a list of all chat records, sorted by last_active descending.
  Future<List<Chat>> fetchChatHistory();
}

@freezed
class HotPipeEvent with _$HotPipeEvent {
  const factory HotPipeEvent.delta({
    required String content,
    String? callId,
    String? tool,
  }) = HotPipeDelta;

  const factory HotPipeEvent.system({
    required String text,
  }) = HotPipeSystem;

  const factory HotPipeEvent.finish() = HotPipeFinish;
}
