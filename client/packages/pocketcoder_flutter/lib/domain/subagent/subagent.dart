import 'package:freezed_annotation/freezed_annotation.dart';

part 'subagent.freezed.dart';
part 'subagent.g.dart';

@freezed
class Subagent with _$Subagent {
  const factory Subagent({
    required String id,
    required String subagentId,
    String? delegatingAgentId,
    int? tmuxWindowId,
    String? chat,
    String? delegatingAgent,
    DateTime? created,
    DateTime? updated,
  }) = _Subagent;

  factory Subagent.fromJson(Map<String, dynamic> json) =>
      _$SubagentFromJson(json);
}
