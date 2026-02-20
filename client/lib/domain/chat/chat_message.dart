import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String chat,
    required MessageRole role,
    MessageStatus? engineMessageStatus,
    MessageDelivery? userMessageStatus,
    String? aiEngineMessageId,
    String? parentId,
    String? agentName,
    String? providerName,
    String? modelName,
    double? cost,
    MessageTokens? tokens,
    Map<String, dynamic>? error,
    String? finishReason,
    List<MessagePart>? parts,
    Map<String, dynamic>? metadata,
    @Default(false) bool isLive, // Frontend only state for streaming
    DateTime? created,
    DateTime? updated,
  }) = _ChatMessage;

  factory ChatMessage.fromRecord(RecordModel record) =>
      ChatMessage.fromJson(record.toJson());

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
  @JsonValue('')
  unknown,
}

enum MessageStatus {
  @JsonValue('processing')
  processing,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
  @JsonValue('aborted')
  aborted,
  @JsonValue('')
  unknown,
}

enum MessageDelivery {
  @JsonValue('pending')
  pending,
  @JsonValue('sending')
  sending,
  @JsonValue('delivered')
  delivered,
  @JsonValue('failed')
  failed,
  @JsonValue('')
  unknown,
}

@freezed
class MessageTokens with _$MessageTokens {
  const factory MessageTokens({
    int? input,
    int? output,
    int? reasoning,
    MessageCacheTokens? cache,
  }) = _MessageTokens;

  factory MessageTokens.fromJson(Map<String, dynamic> json) =>
      _$MessageTokensFromJson(json);
}

@freezed
class MessageCacheTokens with _$MessageCacheTokens {
  const factory MessageCacheTokens({
    int? read,
    int? write,
  }) = _MessageCacheTokens;

  factory MessageCacheTokens.fromJson(Map<String, dynamic> json) =>
      _$MessageCacheTokensFromJson(json);
}

Object? _readText(Map<dynamic, dynamic> json, String key) {
  return json['text'] ?? json['content'];
}

@Freezed(unionKey: 'type')
class MessagePart with _$MessagePart {
  // 1. Text
  const factory MessagePart.text({
    // ignore: invalid_annotation_target
    @JsonKey(readValue: _readText) String? text,
    Map<String, dynamic>? metadata,
  }) = MessagePartText;

  @FreezedUnionValue('reasoning')
  const factory MessagePart.reasoning({
    // ignore: invalid_annotation_target
    @JsonKey(readValue: _readText) String? text,
    Map<String, dynamic>? metadata,
  }) = MessagePartReasoning;

  // 3. Tool (OpenCode: 'tool')
  @FreezedUnionValue('tool')
  const factory MessagePart.tool({
    required String tool,
    required String callID,
    required ToolState state,
    Map<String, dynamic>? metadata,
  }) = MessagePartTool;

  // 4. Step Start (OpenCode: 'step-start')
  @FreezedUnionValue('step-start')
  const factory MessagePart.stepStart({
    String? snapshot,
  }) = MessagePartStepStart;

  // 5. Step Finish (OpenCode: 'step-finish')
  @FreezedUnionValue('step-finish')
  const factory MessagePart.stepFinish({
    required String reason,
    double? cost,
    MessageTokens? tokens,
    String? snapshot,
  }) = MessagePartStepFinish;

  // 6. File / Media (OpenCode: 'file')
  @FreezedUnionValue('file')
  const factory MessagePart.file({
    required String mime,
    required String url,
    String? filename,
  }) = MessagePartFile;

  factory MessagePart.fromJson(Map<String, dynamic> json) =>
      _$MessagePartFromJson(json);
}

@Freezed(unionKey: 'status')
class ToolState with _$ToolState {
  const factory ToolState.pending({
    required Map<String, dynamic> input,
    String? raw,
  }) = ToolStatePending;

  const factory ToolState.running({
    required Map<String, dynamic> input,
    String? title,
  }) = ToolStateRunning;

  @FreezedUnionValue('completed')
  const factory ToolState.completed({
    required Map<String, dynamic> input,
    required String output,
    String? title,
    Map<String, dynamic>? metadata,
  }) = ToolStateCompleted;

  const factory ToolState.error({
    required Map<String, dynamic> input,
    required String error,
    Map<String, dynamic>? metadata,
  }) = ToolStateError;

  factory ToolState.fromJson(Map<String, dynamic> json) =>
      _$ToolStateFromJson(json);
}
