import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/provision_config.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_aeroform/domain/validation/i_validation_service.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

import 'config_state.dart';

/// Cubit for managing deployment configuration state
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
  void updateConfig(ProvisionConfig config) {
    final validation = _validationService.validateProvisionConfig(config);

    emit(state.copyWith(
      config: config,
      validationErrors: validation.fieldErrors,
      isValid: validation.isValid,
    ));
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
}
