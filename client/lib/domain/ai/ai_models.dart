import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_models.freezed.dart';
part 'ai_models.g.dart';

@freezed
class AiAgent with _$AiAgent {
  const factory AiAgent({
    required String id,
    required String name,
    @JsonKey(name: 'is_init') @Default(false) bool isInit,
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
