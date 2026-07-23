import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';

part 'provider_state.freezed.dart';

@freezed
sealed class ProviderState with _$ProviderState implements IUiFlowState {
  const ProviderState._();

  const factory ProviderState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<Harnesse> harnesses,
    @Default([]) List<Model> models,
    @Default([]) List<HarnessModel> harnessModels,
    @Default([]) List<ProviderKey> providerKeys,
    Object? error,
  }) = _ProviderState;

  factory ProviderState.initial() => const ProviderState();

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
