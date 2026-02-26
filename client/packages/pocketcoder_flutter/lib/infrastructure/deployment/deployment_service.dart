import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deployment_service.dart';
import 'package:pocketcoder_flutter/domain/models/cloud_provider.dart';
import 'package:pocketcoder_flutter/domain/models/deployment_config.dart';
import 'package:pocketcoder_flutter/domain/models/deployment_result.dart';
import 'package:pocketcoder_flutter/domain/models/instance.dart';
import 'package:pocketcoder_flutter/domain/models/instance_credentials.dart';
import 'package:pocketcoder_flutter/domain/models/validation_result.dart';
import 'package:pocketcoder_flutter/domain/security/i_certificate_manager.dart';
import 'package:pocketcoder_flutter/domain/security/i_password_generator.dart';
import 'package:pocketcoder_flutter/domain/storage/i_secure_storage.dart';
import 'package:pocketcoder_flutter/domain/validation/i_validation_service.dart';

/// Deployment service implementation that orchestrates instance deployment,
/// monitors progress, and manages deployment lifecycle.
///
/// Uses exponential backoff polling (starts at 15s, max 20 attempts) to monitor
/// deployment readiness via certificate fingerprint endpoint.
@LazySingleton(as: IDeploymentService)
class DeploymentService implements IDeploymentService {
  static const int _maxPollingAttempts = 20;
  static const Duration _initialPollingInterval = Duration(seconds: 15);
  static const String _pocketCoderLabelPrefix = 'pocketcoder';

  final ICloudProviderAPIClient _apiClient;
  final ICertificateManager _certManager;
  final IPasswordGenerator _passwordGenerator;
  final ISecureStorage _secureStorage;
  final IValidationService _validationService;

  // Polling state
  bool _isMonitoring = false;
  int _pollingAttempts = 0;
  Timer? _pollingTimer;
  String? _currentInstanceId;

  DeploymentService({
    required ICloudProviderAPIClient apiClient,
    required ICertificateManager certManager,
    required IPasswordGenerator passwordGenerator,
    required ISecureStorage secureStorage,
    required IValidationService validationService,
  })  : _apiClient = apiClient,
        _certManager = certManager,
        _passwordGenerator = passwordGenerator,
        _secureStorage = secureStorage,
        _validationService = validationService;

  @override
  ValidationResult validateConfig(DeploymentConfig config) {
    return _validationService.validateDeploymentConfig(config);
  }

  @override
  Future<DeploymentResult> deploy(DeploymentConfig config) async {
    // Validate configuration first
    final validation = validateConfig(config);
    if (!validation.isValid) {
      return DeploymentResult(
        instanceId: '',
        ipAddress: '',
        status: DeploymentStatus.failed,
        errorMessage: validation.errorMessage ?? 'Configuration validation failed',
      );
    }

    // Generate secure passwords
    final adminPassword = await _passwordGenerator.generateAdminPassword();
    final rootPassword = await _passwordGenerator.generateRootPassword();

    // Prepare metadata with passwords
    final metadata = config.toMetadata();
    metadata['admin_password'] = adminPassword;
    metadata['root_password'] = rootPassword;
    metadata['cloud_init_url'] = config.cloudInitTemplateUrl;

    // Get access token for API calls
    final accessToken = await _secureStorage.getAccessToken();
    if (accessToken == null) {
      return DeploymentResult(
        instanceId: '',
        ipAddress: '',
        status: DeploymentStatus.failed,
        errorMessage: 'Not authenticated. Please sign in first.',
      );
    }

    try {
      // Create instance via Linode API
      final instance = await _apiClient.createInstance(
        accessToken: accessToken,
        planType: config.planType,
        region: config.region,
        image: 'linode/ubuntu22.04',
        rootPassword: rootPassword,
        metadata: metadata,
      );

      // Store instance credentials securely
      final credentials = InstanceCredentials(
        instanceId: instance.id,
        adminPassword: adminPassword,
        rootPassword: rootPassword,
        adminEmail: config.adminEmail,
      );
      await _secureStorage.storeInstanceCredentials(credentials);

      return DeploymentResult(
        instanceId: instance.id,
        ipAddress: instance.ipAddress,
        status: DeploymentStatus.creating,
      );
    } catch (e) {
      return DeploymentResult(
        instanceId: '',
        ipAddress: '',
        status: DeploymentStatus.failed,
        errorMessage: 'Failed to create instance: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> monitorDeployment(String instanceId) async {
    if (_isMonitoring) {
      // Already monitoring, ignore duplicate call
      return;
    }

    _isMonitoring = true;
    _currentInstanceId = instanceId;
    _pollingAttempts = 0;

    await _startPolling(instanceId);
  }

  Future<void> _startPolling(String instanceId) async {
    _pollingTimer?.cancel();
    _pollingAttempts = 0;

    await _pollForCertificate(instanceId);
  }

  Future<void> _pollForCertificate(String instanceId) async {
    // Get instance details to get IP address
    final accessToken = await _secureStorage.getAccessToken();
    if (accessToken == null) {
      _isMonitoring = false;
      return;
    }

    try {
      final instance = await _apiClient.getInstance(instanceId, accessToken);
      final ipAddress = instance.ipAddress;

      // Try to retrieve certificate fingerprint
      final fingerprint = await _certManager.retrieveCertificateFingerprint(
        ipAddress,
        port: 443,
      );

      // Success! Store fingerprint and complete
      await _certManager.storeFingerprint(instanceId, fingerprint);
      _isMonitoring = false;
      _pollingTimer?.cancel();
    } on HttpException catch (e) {
      // Certificate not ready yet, continue polling
      await _scheduleNextPoll(instanceId);
    } on SocketException catch (_) {
      // Connection refused, instance not ready yet
      await _scheduleNextPoll(instanceId);
    } on TimeoutException catch (_) {
      // Connection timed out, continue polling
      await _scheduleNextPoll(instanceId);
    } catch (e) {
      // Other errors, continue polling
      await _scheduleNextPoll(instanceId);
    }
  }

  Future<void> _scheduleNextPoll(String instanceId) async {
    _pollingAttempts++;

    if (_pollingAttempts >= _maxPollingAttempts) {
      // Timeout reached
      _isMonitoring = false;
      _pollingTimer?.cancel();
      return;
    }

    // Exponential backoff: 15s, 30s, 60s, 120s, etc.
    final delay = _initialPollingInterval * (1 << (_pollingAttempts - 1));

    _pollingTimer = Timer(delay, () => _pollForCertificate(instanceId));
  }

  @override
  void cancelMonitoring() {
    _isMonitoring = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentInstanceId = null;
    _pollingAttempts = 0;
  }

  @override
  Future<InstanceStatus> getInstanceStatus(String instanceId) async {
    final accessToken = await _secureStorage.getAccessToken();
    if (accessToken == null) {
      throw Exception('Not authenticated');
    }

    final instance = await _apiClient.getInstance(instanceId, accessToken);
    return _mapCloudInstanceStatus(instance.status);
  }

  InstanceStatus _mapCloudInstanceStatus(CloudInstanceStatus status) {
    switch (status) {
      case CloudInstanceStatus.creating:
        return InstanceStatus.creating;
      case CloudInstanceStatus.provisioning:
        return InstanceStatus.provisioning;
      case CloudInstanceStatus.running:
        return InstanceStatus.running;
      case CloudInstanceStatus.offline:
        return InstanceStatus.offline;
      case CloudInstanceStatus.failed:
        return InstanceStatus.failed;
    }
  }

  @override
  Future<List<Instance>> getExistingInstances() async {
    final accessToken = await _secureStorage.getAccessToken();
    if (accessToken == null) {
      return [];
    }

    // Filter by PocketCoder label prefix
    final instances = await _apiClient.listInstances(
      accessToken,
      labelFilter: _pocketCoderLabelPrefix,
    );

    return instances.map((cloudInstance) => Instance(
      id: cloudInstance.id,
      label: cloudInstance.label,
      ipAddress: cloudInstance.ipAddress,
      status: _mapCloudInstanceStatus(cloudInstance.status),
      created: cloudInstance.created,
      region: cloudInstance.region,
      planType: cloudInstance.planType,
      provider: cloudInstance.provider,
    )).toList();
  }

  /// Returns the current polling state for testing purposes
  bool get isMonitoring => _isMonitoring;
  int get pollingAttempts => _pollingAttempts;
}