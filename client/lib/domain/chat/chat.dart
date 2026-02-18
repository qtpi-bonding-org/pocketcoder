import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

@freezed
class Chat with _$Chat {
  const factory Chat({
    required String id,
    required String title,
    @JsonKey(name: 'user') String? userId,
    @JsonKey(name: 'agent_id') String? agentId,
    @JsonKey(name: 'agent') String? agent,
    @JsonKey(name: 'last_active') DateTime? lastActive,
    String? preview,
    String? turn,
    DateTime? created,
    DateTime? updated,
  }) = _Chat;

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);
}
