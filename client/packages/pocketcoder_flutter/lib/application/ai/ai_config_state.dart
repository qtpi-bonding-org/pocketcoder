import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/ai/ai_models.dart';

part 'ai_config_state.freezed.dart';

@freezed
class AiConfigState with _$AiConfigState {
  const factory AiConfigState({
    @Default(false) bool isLoading,
    @Default([]) List<AiAgent> agents,
    @Default([]) List<AiPrompt> prompts,
    @Default([]) List<AiModel> models,
    String? error,
  }) = _AiConfigState;
}
