import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deployment_service.dart';
import 'package:pocketcoder_flutter/domain/models/deployment_config.dart';
import 'package:pocketcoder_flutter/domain/models/deployment_result.dart';
import 'package:pocketcoder_flutter/domain/models/instance.dart';
import '../../support/extensions/cubit_ui_flow_extension.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

import 'deployment_state.dart';

/// Cubit for managing deployment operations and instance lifecycle
@injectable
class DeploymentCubit extends AppCubit<DeploymentState> {
  static const int _maxPollingAttempts = 20;
  static const Duration _statusRefreshInterval = Duration(seconds: 30);

  final IDeploymentService _deploymentService;

  // Monitoring state
  Timer? _pollingTimer;
  Timer? _statusRefreshTimer;
  bool _isMonitoring = false;
  int _pollingAttempts = 0;

  DeploymentCubit(
    this._deploymentService,
  ) : super(DeploymentState.initial());

  /// Deploys a new instance with the given configuration
  Future<void> deploy(DeploymentConfig config) async {
    return tryOperation(() async {
      // Validate configuration first
      final validation = _deploymentService.validateConfig(config);
      if (!validation.isValid) {
        throw DeploymentValidationException(
          validation.errorMessage ?? 'Configuration validation failed',
          validation.fieldErrors,
        );
      }

      // Perform deployment
      final result = await _deploymentService.deploy(config);

      if (result.status == DeploymentStatus.failed) {
        throw DeploymentException(result.errorMessage ?? 'Deployment failed');
      }

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

  /// Starts monitoring deployment progress
  Future<void> monitorDeployment(String instanceId) async {
    if (_isMonitoring) {
      return;
    }

    _isMonitoring = true;
    _pollingAttempts = 0;

    await _startPolling(instanceId);
  }

  Future<void> _startPolling(String instanceId) async {
    _pollingTimer?.cancel();
    _pollingAttempts = 0;

    await _pollForCompletion(instanceId);
  }

  Future<void> _pollForCompletion(String instanceId) async {
    _pollingAttempts++;

    try {
      final status = await _deploymentService.getInstanceStatus(instanceId);

      // Update state with current status
      emit(state.copyWith(
        deploymentStatus: _mapToDeploymentStatus(status),
        pollingAttempts: _pollingAttempts,
      ));

      // Check if deployment is complete
      if (status == InstanceStatus.running) {
        _isMonitoring = false;
        _pollingTimer?.cancel();

        // Get instance details
        final instances = await _deploymentService.getExistingInstances();
        final instance = instances.firstWhere(
          (i) => i.id == instanceId,
          orElse: () => throw Exception('Instance not found'),
        );

        emit(state.copyWith(
          status: UiFlowStatus.success,
          instance: instance,
          deploymentStatus: DeploymentStatus.ready,
        ));
        return;
      }

      // Check for timeout
      if (_pollingAttempts >= _maxPollingAttempts) {
        _isMonitoring = false;
        _pollingTimer?.cancel();

        emit(state.copyWith(
          status: UiFlowStatus.failure,
          error: Exception('Deployment timed out after $_pollingAttempts attempts'),
          deploymentStatus: DeploymentStatus.failed,
        ));
        return;
      }

      // Schedule next poll with exponential backoff
      final delay = _getPollingDelay();
      _pollingTimer = Timer(delay, () => _pollForCompletion(instanceId));
    } catch (e) {
      _pollingAttempts++;

      if (_pollingAttempts >= _maxPollingAttempts) {
        _isMonitoring = false;
        _pollingTimer?.cancel();

        emit(state.copyWith(
          status: UiFlowStatus.failure,
          error: e,
          deploymentStatus: DeploymentStatus.failed,
        ));
        return;
      }

      // Schedule next poll
      final delay = _getPollingDelay();
      _pollingTimer = Timer(delay, () => _pollForCompletion(instanceId));
    }
  }

  Duration _getPollingDelay() {
    // Exponential backoff: 15s, 30s, 60s, 120s, etc.
    final baseDelay = const Duration(seconds: 15);
    return baseDelay * (1 << (_pollingAttempts - 1));
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
    _pollingTimer?.cancel();
    _pollingTimer = null;
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