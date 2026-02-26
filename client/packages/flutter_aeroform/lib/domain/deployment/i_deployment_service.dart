import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:flutter_aeroform/domain/models/deployment_result.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_aeroform/domain/models/validation_result.dart';

abstract class IDeploymentService {
  /// Validates deployment configuration
  ValidationResult validateConfig(DeploymentConfig config);

  /// Initiates instance deployment
  Future<DeploymentResult> deploy(DeploymentConfig config);

  /// Polls instance for readiness
  Future<void> monitorDeployment(String instanceId);

  /// Retrieves instance status from API
  Future<InstanceStatus> getInstanceStatus(String instanceId);

  /// Cancels ongoing deployment monitoring
  void cancelMonitoring();

  /// Checks for existing instances to prevent duplicates
  Future<List<Instance>> getExistingInstances();
}