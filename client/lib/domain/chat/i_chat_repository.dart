import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'chat_message.dart';

part 'i_chat_repository.freezed.dart';

abstract class IChatRepository {
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
  Stream<RecordModel> watchChat(String chatId);
}

@freezed
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
