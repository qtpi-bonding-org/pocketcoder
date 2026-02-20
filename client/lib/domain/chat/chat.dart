import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

@freezed
class Chat with _$Chat {
  const factory Chat({
    required String id,
    required String title,
    @JsonKey(name: 'ai_engine_session_id') String? aiEngineSessionId,
    @JsonKey(name: 'engine_type') ChatEngineType? engineType,
    @JsonKey(name: 'user') required String userId,
    @JsonKey(name: 'agent') String? agentId,
    @JsonKey(name: 'last_active') DateTime? lastActive,
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
