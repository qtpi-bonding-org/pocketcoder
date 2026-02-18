import 'package:freezed_annotation/freezed_annotation.dart';

part 'subagent.freezed.dart';
part 'subagent.g.dart';

@freezed
class Subagent with _$Subagent {
  const factory Subagent({
    required String id,
    @JsonKey(name: 'subagent_id') required String subagentId,
    @JsonKey(name: 'delegating_agent_id') required String delegatingAgentId,
    @JsonKey(name: 'tmux_window_id') int? tmuxWindowId,
    @JsonKey(name: 'chat') String? chatId,
    @JsonKey(name: 'delegating_agent') String? delegatingAgentRecordId,
    DateTime? created,
    DateTime? updated,
  }) = _Subagent;

  factory Subagent.fromJson(Map<String, dynamic> json) =>
      _$SubagentFromJson(json);
}
