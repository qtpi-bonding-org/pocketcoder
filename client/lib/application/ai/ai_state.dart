import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/ai/ai_models.dart';

part 'ai_state.freezed.dart';

@freezed
class AiState with _$AiState {
  const factory AiState({
    @Default(false) bool isLoading,
    @Default([]) List<AiAgent> agents,
    @Default([]) List<AiPrompt> prompts,
    @Default([]) List<AiModel> models,
    String? error,
  }) = _AiState;
}
