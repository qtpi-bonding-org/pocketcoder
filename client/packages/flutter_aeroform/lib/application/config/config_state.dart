import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'config_state.freezed.dart';

/// Configuration state for deployment settings
@freezed
class ConfigState with _$ConfigState implements IUiFlowState {
  const ConfigState._();

  const factory ConfigState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    DeploymentConfig? config,
    Map<String, String>? validationErrors,
    List<InstancePlan>? plans,
    List<Region>? regions,
    bool? isValid,
  }) = _ConfigState;

  factory ConfigState.initial() => const ConfigState();

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