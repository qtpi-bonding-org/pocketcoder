import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'ai_models.freezed.dart';
part 'ai_models.g.dart';

enum AiAgentMode {
  @JsonValue('primary')
  primary,
  @JsonValue('subagent')
  subagent,
  @JsonValue('')
  unknown,
}

@freezed
class AiAgent with _$AiAgent {
  const factory AiAgent({
    required String id,
    required String name,
    required String description,
    required AiAgentMode mode,
    required double temperature,
    required bool isInit,
    String? prompt,
    String? model,
    @Default({}) Map<String, dynamic> tools,
    @Default({}) Map<String, dynamic> permissions,
    DateTime? created,
    DateTime? updated,
  }) = _AiAgent;

  factory AiAgent.fromRecord(RecordModel record) =>
      AiAgent.fromJson(record.toJson());

  factory AiAgent.fromJson(Map<String, dynamic> json) =>
      _$AiAgentFromJson(json);
}

@freezed
class AiPrompt with _$AiPrompt {
  const factory AiPrompt({
    required String id,
    required String name,
    required String body,
    DateTime? created,
    DateTime? updated,
  }) = _AiPrompt;

  factory AiPrompt.fromRecord(RecordModel record) =>
      AiPrompt.fromJson(record.toJson());

  factory AiPrompt.fromJson(Map<String, dynamic> json) =>
      _$AiPromptFromJson(json);
}

@freezed
class AiModel with _$AiModel {
  const factory AiModel({
    required String id,
    required String name,
    required String identifier,
    DateTime? created,
    DateTime? updated,
  }) = _AiModel;

  factory AiModel.fromRecord(RecordModel record) =>
      AiModel.fromJson(record.toJson());

  factory AiModel.fromJson(Map<String, dynamic> json) =>
      _$AiModelFromJson(json);
}
