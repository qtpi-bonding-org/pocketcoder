import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'message.freezed.dart';
part 'message.g.dart';

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String chat,
    required MessageRole role,
    MessageEngineMessageStatus? engineMessageStatus,
    MessageUserMessageStatus? userMessageStatus,
    String? aiEngineMessageId,
    String? parentId,
    dynamic parts,
    DateTime? created,
    DateTime? updated,
    MessageErrorDomain? errorDomain,
    dynamic errorPayload,
  }) = _Message;

  factory Message.fromRecord(RecordModel record) =>
      Message.fromJson(record.toJson());

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}

enum MessageRole {
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
  @JsonValue('system')
  system,
  @JsonValue('__unknown__')
  unknown,
}

enum MessageEngineMessageStatus {
  @JsonValue('processing')
  processing,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
  @JsonValue('aborted')
  aborted,
  @JsonValue('__unknown__')
  unknown,
}

enum MessageUserMessageStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('sending')
  sending,
  @JsonValue('delivered')
  delivered,
  @JsonValue('failed')
  failed,
  @JsonValue('__unknown__')
  unknown,
}

enum MessageErrorDomain {
  @JsonValue('infrastructure')
  infrastructure,
  @JsonValue('provider')
  provider,
  @JsonValue('__unknown__')
  unknown,
}
