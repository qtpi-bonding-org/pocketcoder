import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

@freezed
class Chat with _$Chat {
  const factory Chat({
    required String id,
    required String title,
    String? aiEngineSessionId,
    ChatEngineType? engineType,
    required String user,
    String? agent,
    DateTime? lastActive,
    String? preview,
    ChatTurn? turn,
    String? description,
    @Default(false) bool archived,
    @Default('') String tags,
    DateTime? created,
    DateTime? updated,
  }) = _Chat;

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);
}

enum ChatEngineType {
  @JsonValue('opencode')
  opencode,
  @JsonValue('claude-code')
  claudeCode,
  @JsonValue('cursor')
  cursor,
  @JsonValue('custom')
  custom,
  @JsonValue('')
  unknown,
}

enum ChatTurn {
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
  @JsonValue('')
  unknown,
}
