import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';

part 'i_communication_repository.freezed.dart';

abstract class ICommunicationRepository {
  /// Stream of finalized messages from the history (Cold Pipe)
  Stream<List<Message>> watchColdPipe(String chatId);

  /// Stream of ephemeral terminal events (Hot Pipe)
  Stream<HotPipeEvent> watchHotPipe(String chatId);

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

  /// Returns the full URL for a workspace artifact.
  String getArtifactUrl(String path);

  /// Fetches the raw content of an artifact.
  Future<String> fetchArtifact(String path);
}

@freezed
class HotPipeEvent with _$HotPipeEvent {
  const factory HotPipeEvent.textDelta({
    required String messageId,
    required String partId,
    required String text,
  }) = HotPipeTextDelta;

  const factory HotPipeEvent.toolStatus({
    required String messageId,
    required String partId,
    required String tool,
    required String status,
  }) = HotPipeToolStatus;

  const factory HotPipeEvent.snapshot({
    required String messageId,
    required List<Map<String, dynamic>> parts,
    String? role,
  }) = HotPipeSnapshot;

  const factory HotPipeEvent.complete({
    required String messageId,
    required List<Map<String, dynamic>> parts,
    String? status,
    String? role,
  }) = HotPipeComplete;

  const factory HotPipeEvent.error({
    required String messageId,
    required Map<String, dynamic> error,
  }) = HotPipeError;
}
