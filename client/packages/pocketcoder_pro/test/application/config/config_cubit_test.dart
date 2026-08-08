import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:flutter_aeroform/domain/models/provision_config.dart';
import 'package:flutter_aeroform/domain/models/validation_result.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_aeroform/domain/validation/i_validation_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_pro/application/config/config_cubit.dart';

class MockValidationService extends Mock implements IValidationService {}

class MockCloudProviderAPIClient extends Mock
    implements ICloudProviderAPIClient {}

class MockSecureStorage extends Mock implements ISecureStorage {}

ProvisionConfig _testConfig() => ProvisionConfig(
      planType: 'g6-standard-2',
      region: 'us-east',
    );

void main() {
  late MockValidationService validationService;
  late MockCloudProviderAPIClient apiClient;
  late MockSecureStorage secureStorage;
  late ConfigCubit cubit;

  setUp(() {
    validationService = MockValidationService();
    apiClient = MockCloudProviderAPIClient();
    secureStorage = MockSecureStorage();
    cubit = ConfigCubit(validationService, apiClient, secureStorage);
  });

  test('updateConfig emits the new config and its validation result', () {
    final config = _testConfig();
    when(() => validationService.validateProvisionConfig(config))
        .thenReturn(ValidationResult.valid());

    cubit.updateConfig(config);

    expect(cubit.state.config, config);
    expect(cubit.state.isValid, isTrue);
  });
}
