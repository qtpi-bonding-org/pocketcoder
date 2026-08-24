import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

@freezed
abstract class Chat with _$Chat {
  const factory Chat({
    required String id,
    required String title,
    required String user,
    DateTime? lastActive,
    String? preview,
    @JsonKey(unknownEnumValue: ChatTurn.unknown) ChatTurn? turn,
    String? description,
    bool? archived,
    String? tags,
    DateTime? created,
    DateTime? updated,
    String? agentProfile,
    String? harnessModelOverride,
    String? ollamaModelOverride,
    String? harness,
    dynamic workspaceOverride,
    bool? monitored,
  }) = _Chat;

  factory Chat.fromRecord(RecordModel record) =>
      Chat.fromJson(record.toJson());

  factory Chat.fromJson(Map<String, dynamic> json) =>
      _$ChatFromJson(json);
}

enum ChatTurn {
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
  @JsonValue('__unknown__')
  unknown,
}
