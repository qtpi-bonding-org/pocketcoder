import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_aeroform/domain/models/provision_result.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/domain/deployment/server_status_document.dart';

part 'deployment_state.freezed.dart';

/// Deployment state for managing instance deployment lifecycle
@freezed
sealed class DeploymentState with _$DeploymentState implements IUiFlowState {
  const DeploymentState._();

  const factory DeploymentState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    Instance? instance,
    ProvisionResult? deploymentResult,
    @Default(0) int pollingAttempts,
    DateTime? deploymentStartedAt,
    OnboardingStage? deploymentStatus,
    ServerStatusDocument? serverStatusDocument,
    String? instanceId,
    String? hostname,
    ProvisionBackendKind? backend,
  }) = _DeploymentState;

  factory DeploymentState.initial() => const DeploymentState();

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
