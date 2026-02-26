import 'package:injectable/injectable.dart';
import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:flutter_aeroform/domain/models/validation_result.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_aeroform/domain/validation/i_validation_service.dart';
import '../../support/extensions/cubit_ui_flow_extension.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

import 'config_state.dart';

/// Cubit for managing deployment configuration state
@injectable
class ConfigCubit extends AppCubit<ConfigState> {
  final IValidationService _validationService;
  final ICloudProviderAPIClient _apiClient;
  final ISecureStorage _secureStorage;

  ConfigCubit(
    this._validationService,
    this._apiClient,
    this._secureStorage,
  ) : super(ConfigState.initial());

  /// Updates the deployment configuration
  void updateConfig(DeploymentConfig config) {
    final validation = _validationService.validateDeploymentConfig(config);

    emit(state.copyWith(
      config: config,
      validationErrors: validation.fieldErrors,
      isValid: validation.isValid,
    ));
  }

  /// Validates the current configuration
  ValidationResult validateConfig() {
    if (state.config == null) {
      return ValidationResult.invalid('No configuration provided');
    }

    return _validationService.validateDeploymentConfig(state.config!);
  }

  /// Loads available plans from the cloud provider
  Future<void> loadPlans() async {
    return tryOperation(() async {
      final accessToken = await _secureStorage.getAccessToken();
      if (accessToken == null) {
        throw Exception('Not authenticated');
      }
      final plans = await _apiClient.getAvailablePlans(accessToken);

      return state.copyWith(
        status: UiFlowStatus.success,
        plans: plans,
      );
    });
  }

  /// Loads available regions from the cloud provider
  Future<void> loadRegions() async {
    return tryOperation(() async {
      final accessToken = await _secureStorage.getAccessToken();
      if (accessToken == null) {
        throw Exception('Not authenticated');
      }
      final regions = await _apiClient.getAvailableRegions(accessToken);

      return state.copyWith(
        status: UiFlowStatus.success,
        regions: regions,
      );
    });
  }

  /// Loads both plans and regions
  Future<void> loadPlansAndRegions() async {
    return tryOperation(() async {
      final accessToken = await _secureStorage.getAccessToken();
      if (accessToken == null) {
        throw Exception('Not authenticated');
      }
      final Future<List<InstancePlan>> plansFuture = _apiClient.getAvailablePlans(accessToken);
      final Future<List<Region>> regionsFuture = _apiClient.getAvailableRegions(accessToken);

      final results = await Future.wait([plansFuture, regionsFuture]);

      return state.copyWith(
        status: UiFlowStatus.success,
        plans: results[0] as List<InstancePlan>,
        regions: results[1] as List<Region>,
      );
    });
  }

  /// Clears the current configuration
  void clearConfig() {
    emit(ConfigState.initial());
  }
}