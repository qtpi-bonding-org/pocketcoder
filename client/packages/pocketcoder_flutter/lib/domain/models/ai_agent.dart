import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'ai_agent.freezed.dart';
part 'ai_agent.g.dart';

@freezed
class AiAgent with _$AiAgent {
  const factory AiAgent({
    required String id,
    required String name,
    String? description,
    AiAgentMode? mode,
    double? temperature,
    bool? isInit,
    String? prompt,
    String? model,
    dynamic tools,
    dynamic permissions,
  }) = _AiAgent;

  factory AiAgent.fromRecord(RecordModel record) =>
      AiAgent.fromJson(record.toJson());

  factory AiAgent.fromJson(Map<String, dynamic> json) =>
      _$AiAgentFromJson(json);
}

enum AiAgentMode {
  @JsonValue('primary')
  primary,
  @JsonValue('subagent')
  subagent,
  @JsonValue('__unknown__')
  unknown,
}
