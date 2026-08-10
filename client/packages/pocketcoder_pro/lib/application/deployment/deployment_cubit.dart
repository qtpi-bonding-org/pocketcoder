import 'dart:async';

import 'package:flutter_aeroform/domain/deployment/i_provisioning_service.dart';
import 'package:flutter_aeroform/domain/models/app_bootstrap.dart';
import 'package:flutter_aeroform/domain/models/host_spec.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_aeroform/domain/models/instance_credentials.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_aeroform/domain/models/provision_config.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_pro/domain/deployment/deployment_phase.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/deployment_readiness_service.dart';
import 'package:pocketcoder_pro/infrastructure/server_update/current_instance_store.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_credentials.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/selected_cloud_provider.dart';

import 'deployment_state.dart';

class DeploymentCubit extends AppCubit<DeploymentState> {
  DeploymentCubit(
    this._provisioningService,
    this._currentInstanceStore,
    this._readinessService,
    this._secureStorage,
    this._credentialStore,
  ) : super(DeploymentState.initial());

  final IProvisioningService _provisioningService;
  final CurrentInstanceStore _currentInstanceStore;
  final DeploymentReadinessService _readinessService;
  final ISecureStorage _secureStorage;
  final PocketCoderCredentialStore _credentialStore;
  Timer? _statusRefreshTimer;
  bool _isMonitoring = false;

  Future<void> deploy(
    ProvisionConfig config, {
    required HostSpec host,
    required AppBootstrap appBootstrap,
    InstanceCredentials? instanceCredentials,
    PocketCoderCredentials? pocketCoderCredentials,
  }) async {
    await tryOperation(() async {
      final validation = _provisioningService.validateConfig(config);
      if (!validation.isValid) {
        throw DeploymentValidationException(
          validation.errorMessage ?? 'Configuration validation failed',
          validation.fieldErrors,
        );
      }
      emit(state.copyWith(
        status: UiFlowStatus.loading,
        deploymentStatus: OnboardingStage.validating,
        instance: null,
        instanceId: null,
      ));
      final result = await _provisioningService.provision(
        config,
        host: host,
        appBootstrap: appBootstrap,
        onProgress: _onProvisionProgress,
      );
      await _currentInstanceStore.save(result.instanceId);
      if (instanceCredentials != null) {
        await _secureStorage.storeInstanceCredentials(
          instanceCredentials.copyWith(instanceId: result.instanceId),
        );
      }
      if (pocketCoderCredentials != null) {
        await _credentialStore.store(PocketCoderCredentials(
          instanceId: result.instanceId,
          adminEmail: pocketCoderCredentials.adminEmail,
          adminPassword: pocketCoderCredentials.adminPassword,
        ));
      }
      emit(state.copyWith(
        status: UiFlowStatus.loading,
        deploymentResult: result,
        instanceId: result.instanceId,
        hostname: result.hostname,
        deploymentStatus: OnboardingStage.hostReady,
      ));
      unawaited(monitorDeployment(
          hostname: result.hostname, instanceId: result.instanceId));
      return state;
    }, emitLoading: true);
  }

  void _onProvisionProgress(ProvisionProgress progress) {
    final stage = switch (progress.phase) {
      ProvisionPhase.validating => OnboardingStage.validating,
      ProvisionPhase.creatingProviderResource => OnboardingStage.creatingServer,
      ProvisionPhase.preparingHost => OnboardingStage.preparingHost,
      ProvisionPhase.hostProvisioned => OnboardingStage.hostReady,
      ProvisionPhase.failed ||
      ProvisionPhase.cancelled =>
        OnboardingStage.failed,
    };
    emit(state.copyWith(
      status: stage == OnboardingStage.failed
          ? UiFlowStatus.failure
          : UiFlowStatus.loading,
      deploymentStatus: stage,
      instanceId: progress.instanceId ?? state.instanceId,
      error: progress.errorMessage == null
          ? state.error
          : Exception(progress.errorMessage),
    ));
  }

  Future<void> monitorDeployment(
      {required String hostname, required String instanceId}) async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    try {
      await for (final update in _readinessService.monitor(
        hostname: hostname,
        instanceId: instanceId,
      )) {
        final stage = update.phase.toOnboardingStage();
        emit(state.copyWith(
          status: stage == OnboardingStage.failed
              ? UiFlowStatus.failure
              : stage == OnboardingStage.ready
                  ? UiFlowStatus.success
                  : UiFlowStatus.loading,
          deploymentStatus: stage,
          pollingAttempts: update.pollingAttempt,
          serverStatusDocument:
              update.statusDocument ?? state.serverStatusDocument,
        ));
      }
    } finally {
      _isMonitoring = false;
    }
  }

  Future<void> refreshInstanceStatus(String instanceId) async {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshStatus(instanceId),
    );
    await _refreshStatus(instanceId);
  }

  Future<void> loadInstance(String instanceId) async {
    final instances = await _provisioningService.getExistingInstances(
      labelPrefix: pocketCoderHostLabelPrefix,
      provider: selectedCloudProvider,
    );
    for (final instance in instances) {
      if (instance.id == instanceId) {
        emit(state.copyWith(instance: instance, instanceId: instanceId));
        return;
      }
    }
  }

  Future<void> _refreshStatus(String instanceId) async {
    try {
      final status = await _provisioningService.getInstanceStatus(
        instanceId,
        provider: selectedCloudProvider,
      );
      final instances = await _provisioningService.getExistingInstances(
        labelPrefix: pocketCoderHostLabelPrefix,
        provider: selectedCloudProvider,
      );
      Instance? instance;
      for (final item in instances) {
        if (item.id == instanceId) {
          instance = item;
          break;
        }
      }
      if (instance != null) {
        emit(state.copyWith(instance: instance.copyWith(status: status)));
      }
    } on Object {
      // Provider power state is advisory and must not grant readiness.
    }
  }

  void cancelDeployment() {
    _isMonitoring = false;
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = null;
  }

  void resetDeployment() {
    cancelDeployment();
    emit(DeploymentState.initial());
  }

  bool get isMonitoring => _isMonitoring;
}

class DeploymentValidationException implements Exception {
  const DeploymentValidationException(this.message, [this.fieldErrors]);
  final String message;
  final Map<String, String>? fieldErrors;
  @override
  String toString() => message;
}
