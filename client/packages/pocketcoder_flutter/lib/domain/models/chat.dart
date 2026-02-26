import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

@freezed
class Chat with _$Chat {
  const factory Chat({
    required String id,
    required String title,
    String? aiEngineSessionId,
    @JsonKey(unknownEnumValue: ChatEngineType.unknown) ChatEngineType? engineType,
    required String user,
    String? agent,
    DateTime? lastActive,
    String? preview,
    @JsonKey(unknownEnumValue: ChatTurn.unknown) ChatTurn? turn,
    String? description,
    bool? archived,
    String? tags,
    DateTime? created,
    DateTime? updated,
  }) = _Chat;

  factory Chat.fromRecord(RecordModel record) =>
      Chat.fromJson(record.toJson());

  factory Chat.fromJson(Map<String, dynamic> json) =>
      _$ChatFromJson(json);
}

enum ChatEngineType {
  @JsonValue('opencode')
  opencode,
  @JsonValue('claude-code')
  claude_code,
  @JsonValue('cursor')
  cursor,
  @JsonValue('custom')
  custom,
  @JsonValue('__unknown__')
  unknown,
}

enum ChatTurn {
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
  @JsonValue('__unknown__')
  unknown,
}
