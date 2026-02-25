import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'subagent.freezed.dart';
part 'subagent.g.dart';

@freezed
class Subagent with _$Subagent {
  const factory Subagent({
    required String id,
    required String subagentId,
    required String delegatingAgentId,
    double? tmuxWindowId,
    String? chat,
    String? delegatingAgent,
  }) = _Subagent;

  factory Subagent.fromRecord(RecordModel record) =>
      Subagent.fromJson(record.toJson());

  factory Subagent.fromJson(Map<String, dynamic> json) =>
      _$SubagentFromJson(json);
}
