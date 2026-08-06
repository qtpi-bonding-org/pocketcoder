import 'dart:async';

import 'package:flutter_aeroform/domain/deployment/i_deployment_service.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:flutter_aeroform/domain/models/deployment_result.dart';
import 'package:flutter_aeroform/domain/models/deployment_progress.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

import 'package:pocketcoder_pro/infrastructure/server_update/current_instance_store.dart';

import 'deployment_state.dart';

/// Cubit for managing deployment operations and instance lifecycle
class DeploymentCubit extends AppCubit<DeploymentState> {
  static const Duration _statusRefreshInterval = Duration(seconds: 30);

  final IDeploymentService _deploymentService;
  final CurrentInstanceStore _currentInstanceStore;

  // Monitoring state
  Timer? _statusRefreshTimer;
  bool _isMonitoring = false;
  int _pollingAttempts = 0;

  DeploymentCubit(
    this._deploymentService,
    this._currentInstanceStore,
  ) : super(DeploymentState.initial());

  /// Deploys a new instance with the given configuration
  Future<void> deploy(DeploymentConfig config,
      {required String adminPassword}) async {
    return tryOperation(() async {
      // Validate configuration first
      final validation = _deploymentService.validateConfig(config);
      if (!validation.isValid) {
        throw DeploymentValidationException(
          validation.errorMessage ?? 'Configuration validation failed',
          validation.fieldErrors,
        );
      }

      // Emit uploading image phase before deployment starts
      emit(state.copyWith(
        status: UiFlowStatus.success,
        deploymentStatus: DeploymentStatus.uploadingImage,
      ));

      // Perform deployment (includes image check/upload + instance creation)
      final result = await _deploymentService.deploy(
        config,
        adminPassword: adminPassword,
        onProgress: _onDeploymentProgress,
      );

      if (result.status == DeploymentStatus.failed) {
        throw DeploymentException(result.errorMessage ?? 'Deployment failed');
      }

      // Persist which instance is "the" deployment so the update feature
      // can find it later (e.g. from Settings), not just during this
      // deploy flow's own navigation stack.
      await _currentInstanceStore.save(result.instanceId);

      return state.copyWith(
        status: UiFlowStatus.success,
        deploymentResult: result,
        instanceId: result.instanceId,
        deploymentStatus: result.status,
        deploymentStartedAt: DateTime.now(),
        pollingAttempts: 0,
      );
    }, emitLoading: true);
  }

  void _onDeploymentProgress(DeploymentProgress progress) {
    if (progress.isTerminal) {
      _isMonitoring = false;
    }
    final mapped = _mapProgressPhase(progress.phase);
    emit(state.copyWith(
      status: progress.isTerminal
          ? (progress.phase == DeploymentPhase.failed
              ? UiFlowStatus.failure
              : UiFlowStatus.success)
          : UiFlowStatus.loading,
      deploymentStatus: mapped,
      instanceId: progress.instanceId ?? state.instanceId,
      error: progress.errorMessage == null
          ? state.error
          : Exception(progress.errorMessage),
      pollingAttempts: progress.phase == DeploymentPhase.waitingForServer
          ? state.pollingAttempts + 1
          : state.pollingAttempts,
    ));

    if (progress.phase == DeploymentPhase.ready &&
        progress.instanceId != null) {
      unawaited(_loadReadyInstance(progress.instanceId!));
    }
  }

  Future<void> _loadReadyInstance(String instanceId) async {
    try {
      final instances = await _deploymentService.getExistingInstances();
      final instance = instances.firstWhere((item) => item.id == instanceId);
      emit(state.copyWith(
        status: UiFlowStatus.success,
        instance: instance,
        instanceId: instanceId,
        deploymentStatus: DeploymentStatus.ready,
      ));
    } catch (error) {
      emit(state.copyWith(status: UiFlowStatus.failure, error: error));
    }
  }

  DeploymentStatus _mapProgressPhase(DeploymentPhase phase) {
    switch (phase) {
      case DeploymentPhase.idle:
      case DeploymentPhase.validating:
        return DeploymentStatus.uploadingImage;
      case DeploymentPhase.creatingProviderResource:
        return DeploymentStatus.creating;
      case DeploymentPhase.preparingHost:
      case DeploymentPhase.installingApplication:
      case DeploymentPhase.startingServices:
      case DeploymentPhase.waitingForServer:
        return DeploymentStatus.provisioning;
      case DeploymentPhase.ready:
        return DeploymentStatus.ready;
      case DeploymentPhase.failed:
      case DeploymentPhase.cancelled:
        return DeploymentStatus.failed;
    }
  }

  /// Starts monitoring deployment progress
  Future<void> monitorDeployment(String instanceId) async {
    if (_isMonitoring) {
      return;
    }

    _isMonitoring = true;
    _pollingAttempts = 0;

    await _deploymentService.monitorDeployment(
      instanceId,
      onProgress: _onDeploymentProgress,
    );
  }

  DeploymentStatus _mapToDeploymentStatus(InstanceStatus status) {
    switch (status) {
      case InstanceStatus.creating:
        return DeploymentStatus.creating;
      case InstanceStatus.provisioning:
        return DeploymentStatus.provisioning;
      case InstanceStatus.running:
        return DeploymentStatus.ready;
      case InstanceStatus.offline:
        return DeploymentStatus.failed;
      case InstanceStatus.failed:
        return DeploymentStatus.failed;
    }
  }

  /// Refreshes the instance status every 30 seconds
  Future<void> refreshInstanceStatus(String instanceId) async {
    _statusRefreshTimer?.cancel();

    _statusRefreshTimer = Timer.periodic(
      _statusRefreshInterval,
      (_) => _refreshStatus(instanceId),
    );

    // Initial refresh
    await _refreshStatus(instanceId);
  }

  Future<void> _refreshStatus(String instanceId) async {
    try {
      final status = await _deploymentService.getInstanceStatus(instanceId);

      // Get instance details
      final instances = await _deploymentService.getExistingInstances();
      final instance = instances.firstWhere(
        (i) => i.id == instanceId,
        orElse: () => throw Exception('Instance not found'),
      );

      emit(state.copyWith(
        instance: instance.copyWith(status: status),
        deploymentStatus: _mapToDeploymentStatus(status),
      ));
    } catch (e) {
      // Silently fail on status refresh - not critical
    }
  }

  /// Stops all monitoring and status refresh timers
  void cancelDeployment() {
    _isMonitoring = false;
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = null;
    _pollingAttempts = 0;
  }

  /// Resets the deployment state
  void resetDeployment() {
    cancelDeployment();
    emit(DeploymentState.initial());
  }

  /// Gets the current monitoring state
  bool get isMonitoring => _isMonitoring;
  int get currentPollingAttempts => _pollingAttempts;
}

/// Exception thrown when deployment configuration is invalid
class DeploymentValidationException implements Exception {
  final String message;
  final Map<String, String>? fieldErrors;

  DeploymentValidationException(this.message, [this.fieldErrors]);

  @override
  String toString() => 'DeploymentValidationException: $message';
}

/// Exception thrown when deployment fails
class DeploymentException implements Exception {
  final String message;

  DeploymentException(this.message);

  @override
  String toString() => 'DeploymentException: $message';
}
