import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/llm_key.dart';
import 'package:pocketcoder_flutter/domain/models/model_selection.dart';
import 'package:pocketcoder_flutter/domain/models/llm_provider.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'llm_state.freezed.dart';

@freezed
class LlmState with _$LlmState implements IUiFlowState {
  const LlmState._();

  const factory LlmState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<LlmKey> keys,
    @Default([]) List<LlmProvider> providers,
    @Default([]) List<ModelSelection> configs,
    Object? error,
  }) = _LlmState;

  factory LlmState.initial() => const LlmState();

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
