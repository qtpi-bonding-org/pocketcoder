import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/models/ai_agent.dart';
import 'package:pocketcoder_flutter/domain/models/ai_prompt.dart';
import 'package:pocketcoder_flutter/domain/models/ai_model.dart';

part 'ai_config_state.freezed.dart';

@freezed
class AiConfigState with _$AiConfigState implements IUiFlowState {
  const AiConfigState._();

  const factory AiConfigState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<AiAgent> agents,
    @Default([]) List<AiPrompt> prompts,
    @Default([]) List<AiModel> models,
    Object? error,
  }) = _AiConfigState;

  factory AiConfigState.initial() => const AiConfigState();

  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get hasError => error != null;
}
