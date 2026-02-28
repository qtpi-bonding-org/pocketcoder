import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';

part 'chat_state.freezed.dart';

enum ChatOperation {
  initialize,
  sendMessage,
  loadHistory,
  fetchArtifact,
}

@freezed
class ChatState with _$ChatState implements IUiFlowState {
  const ChatState._();

  const factory ChatState({
    @Default([]) List<Message> messages,
    @Default([]) List<Chat> chats,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default(false) bool isPocoThinking,
    Message? hotMessage,
    String? chatId,
    String? opencodeId,
    String? currentArtifactPath,
    String? currentArtifactContent,
    Object? error,
    ChatOperation? lastOperation,
  }) = _ChatState;

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

  /// Returns a merged list of messages where the [hotMessage] (SSE)
  /// takes priority over the [messages] (DB) if the IDs match.
  List<Message> get displayMessages {
    if (hotMessage == null) return messages;

    // Try to find the cold equivalent by ID or by AI Engine Message ID
    final hotId = hotMessage!.id;
    final hotAiId = hotMessage!.aiEngineMessageId;

    final index = messages.indexWhere((m) {
      if (m.id == hotId) return true;
      if (hotAiId != null && m.aiEngineMessageId == hotAiId) return true;
      return false;
    });

    if (index != -1) {
      // Hot shadows cold
      final newList = List<Message>.from(messages);
      newList[index] = hotMessage!;
      return newList;
    } else {
      // Truly new
      return [...messages, hotMessage!];
    }
  }
}
