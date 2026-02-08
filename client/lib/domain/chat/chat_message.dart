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

Object? _readText(Map<dynamic, dynamic> json, String key) {
  return json['text'] ?? json['content'];
}

@Freezed(unionKey: 'type')
class MessagePart with _$MessagePart {
  // 1. Text
  const factory MessagePart.text({
    // ignore: invalid_annotation_target
    @JsonKey(readValue: _readText) required String text,
  }) = MessagePartText;

  // 2. Tool Call (OpenCode: 'tool-call')
  @FreezedUnionValue('tool-call')
  const factory MessagePart.toolCall({
    required String tool,
    required String callID,
    Map<String, dynamic>? args,
  }) = MessagePartToolCall;

  // 3. Tool Result (OpenCode: 'tool-result')
  @FreezedUnionValue('tool-result')
  const factory MessagePart.toolResult({
    required String tool,
    required String callID,
    String? content,
    bool? isError,
  }) = MessagePartToolResult;

  // 4. Step Start (OpenCode: 'step-start')
  @FreezedUnionValue('step-start')
  const factory MessagePart.stepStart({
    required String id,
  }) = MessagePartStepStart;

  // 5. Step Finish (OpenCode: 'step-finish')
  @FreezedUnionValue('step-finish')
  const factory MessagePart.stepFinish({
    required String id,
    String? reason,
    double? cost,
  }) = MessagePartStepFinish;

  factory MessagePart.fromJson(Map<String, dynamic> json) =>
      _$MessagePartFromJson(json);
}
