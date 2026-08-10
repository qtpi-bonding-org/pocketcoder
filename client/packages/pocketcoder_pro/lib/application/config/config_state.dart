import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/provision_config.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_pro/domain/deployment/harness_catalog.dart';

part 'config_state.freezed.dart';

/// Configuration state for deployment settings
@freezed
sealed class ConfigState with _$ConfigState implements IUiFlowState {
  const ConfigState._();

  const factory ConfigState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    ProvisionConfig? config,
    Map<String, String>? validationErrors,
    List<InstancePlan>? plans,
    List<Region>? regions,
    bool? isValid,
    @Default(<String>[]) List<String> selectedHarnesses,
  }) = _ConfigState;

  factory ConfigState.initial() => ConfigState(
        selectedHarnesses: DeploymentHarnessCatalog.bundled.initialSelection,
      );

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
