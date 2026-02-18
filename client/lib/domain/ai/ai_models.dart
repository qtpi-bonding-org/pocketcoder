import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_models.freezed.dart';
part 'ai_models.g.dart';

@freezed
class AiAgent with _$AiAgent {
  const factory AiAgent({
    required String id,
    required String name,
    String? description,
    @Default(false) bool isInit,
    @JsonKey(name: 'prompt') String? promptId,
    @JsonKey(name: 'model') String? modelId,
    String? config,
    DateTime? created,
    DateTime? updated,
  }) = _AiAgent;

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

  factory AiModel.fromJson(Map<String, dynamic> json) =>
      _$AiModelFromJson(json);
}

@freezed
class AiPermissionRule with _$AiPermissionRule {
  const factory AiPermissionRule({
    required String id,
    required String agent,
    required String pattern,
    required String action,
    DateTime? created,
    DateTime? updated,
  }) = _AiPermissionRule;

  factory AiPermissionRule.fromJson(Map<String, dynamic> json) =>
      _$AiPermissionRuleFromJson(json);
}
