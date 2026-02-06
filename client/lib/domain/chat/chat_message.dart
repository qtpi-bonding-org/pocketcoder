import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String chatId,
    required MessageRole role,
    required List<MessagePart> parts,
    @Default(false) bool isLive,
    DateTime? createdAt,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}

enum MessageRole {
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
  @JsonValue('system')
  system,
}

@freezed
class MessagePart with _$MessagePart {
  const factory MessagePart.text({
    required String content,
  }) = MessagePartText;

  const factory MessagePart.tool({
    required String tool,
    required String callId,
    String? input,
    String? output,
  }) = MessagePartTool;

  factory MessagePart.fromJson(Map<String, dynamic> json) =>
      _$MessagePartFromJson(json);
}
