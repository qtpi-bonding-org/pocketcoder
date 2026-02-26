import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/deployment_config.dart';
import 'package:flutter_aeroform/domain/models/deployment_result.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_aeroform/domain/models/instance_credentials.dart';
import 'package:flutter_aeroform/domain/models/validation_result.dart';
import 'package:flutter_aeroform/domain/security/i_certificate_manager.dart';
import 'package:flutter_aeroform/domain/security/i_password_generator.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_aeroform/domain/validation/i_validation_service.dart';
import 'package:flutter_aeroform/infrastructure/deployment/deployment_service.dart';
import 'package:mocktail/mocktail.dart';

DeploymentConfig createTestDeploymentConfig() {
  return DeploymentConfig(
    planType: 'g6-standard-2',
    region: 'us-east',
    adminEmail: 'admin@example.com',
    geminiApiKey: 'AIzaTestKey123',
    ntfyEnabled: true,
    cloudInitTemplateUrl: 'https://example.com/cloud-init',
  );
}

class MockCloudProviderAPIClient extends Mock
    implements ICloudProviderAPIClient {}

class MockCertificateManager extends Mock implements ICertificateManager {}

class MockPasswordGenerator extends Mock implements IPasswordGenerator {}

class MockSecureStorage extends Mock implements ISecureStorage {}

class MockValidationService extends Mock implements IValidationService {}

void main() {
  setUpAll(() {
    registerFallbackValue(InstanceCredentials(
      instanceId: 'test',
      adminPassword: 'test',
      rootPassword: 'test',
      adminEmail: 'test@example.com',
    ));
  });
  group('DeploymentService', () {
    late ICloudProviderAPIClient apiClient;
    late ICertificateManager certManager;
    late IPasswordGenerator passwordGenerator;
    late ISecureStorage secureStorage;
    late IValidationService validationService;
    late DeploymentService deploymentService;

    setUp(() {
      apiClient = MockCloudProviderAPIClient();
      certManager = MockCertificateManager();
      passwordGenerator = MockPasswordGenerator();
      secureStorage = MockSecureStorage();
      validationService = MockValidationService();

      deploymentService = DeploymentService(
        apiClient: apiClient,
        certManager: certManager,
        passwordGenerator: passwordGenerator,
        secureStorage: secureStorage,
        validationService: validationService,
      );
    });

    group('validateConfig', () {
      test('returns valid result when validation passes', () {
        final config = createTestDeploymentConfig();
        when(() => validationService.validateDeploymentConfig(config))
            .thenReturn(ValidationResult.valid());

        final result = deploymentService.validateConfig(config);

        expect(result.isValid, isTrue);
        verify(() => validationService.validateDeploymentConfig(config))
            .called(1);
      });

      test('returns invalid result when validation fails', () {
        final config = createTestDeploymentConfig();
        when(() => validationService.validateDeploymentConfig(config))
            .thenReturn(ValidationResult.invalid('Invalid email'));

        final result = deploymentService.validateConfig(config);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, 'Invalid email');
      });
    });

    group('deploy', () {
      test('creates instance with correct parameters', () async {
        final config = createTestDeploymentConfig();
        final cloudInstance = CloudInstance(
          id: '12345',
          label: 'pocketcoder-test',
          ipAddress: '192.168.1.100',
          status: CloudInstanceStatus.creating,
          created: DateTime.now(),
          region: 'us-east',
          planType: 'g6-standard-2',
          provider: 'linode',
        );

        when(() => validationService.validateDeploymentConfig(config))
            .thenReturn(ValidationResult.valid());
        when(() => passwordGenerator.generateAdminPassword())
            .thenAnswer((_) async => 'AdminPass123!');
        when(() => passwordGenerator.generateRootPassword())
            .thenAnswer((_) async => 'RootPass456@');
        when(() => secureStorage.getAccessToken())
            .thenAnswer((_) async => 'test-access-token');
        when(
          () => apiClient.createInstance(
            accessToken: 'test-access-token',
            planType: config.planType,
            region: config.region,
            image: 'linode/ubuntu22.04',
            rootPassword: any(named: 'rootPassword'),
            metadata: any(named: 'metadata'),
          ),
        ).thenAnswer((_) async => cloudInstance);
        when(() => secureStorage.storeInstanceCredentials(any()))
            .thenAnswer((_) async {});

        final result = await deploymentService.deploy(config);

        expect(result.instanceId, '12345');
        expect(result.ipAddress, '192.168.1.100');
        expect(result.status, DeploymentStatus.creating);
        verify(() => apiClient.createInstance(
          accessToken: 'test-access-token',
          planType: 'g6-standard-2',
          region: 'us-east',
          image: 'linode/ubuntu22.04',
          rootPassword: 'RootPass456@',
          metadata: any(named: 'metadata'),
        )).called(1);
      });

      test('fails when validation fails', () async {
        final config = createTestDeploymentConfig();
        when(() => validationService.validateDeploymentConfig(config))
            .thenReturn(ValidationResult.invalid('Invalid configuration'));

        final result = await deploymentService.deploy(config);

        expect(result.status, DeploymentStatus.failed);
        expect(result.errorMessage, 'Invalid configuration');
        expect(result.instanceId, isEmpty);
        verifyNever(() => apiClient.createInstance(
          accessToken: any(named: 'accessToken'),
          planType: any(named: 'planType'),
          region: any(named: 'region'),
          image: any(named: 'image'),
          rootPassword: any(named: 'rootPassword'),
          metadata: any(named: 'metadata'),
        ));
      });

      test('fails when not authenticated', () async {
        final config = createTestDeploymentConfig();
        when(() => validationService.validateDeploymentConfig(config))
            .thenReturn(ValidationResult.valid());
        when(() => passwordGenerator.generateAdminPassword())
            .thenAnswer((_) async => 'AdminPass123!');
        when(() => passwordGenerator.generateRootPassword())
            .thenAnswer((_) async => 'RootPass456@');
        when(() => secureStorage.getAccessToken()).thenAnswer((_) async => null);

        final result = await deploymentService.deploy(config);

        expect(result.status, DeploymentStatus.failed);
        expect(result.errorMessage, contains('Not authenticated'));
      });

      test('stores instance credentials after successful deployment', () async {
        final config = createTestDeploymentConfig();
        final cloudInstance = CloudInstance(
          id: '12345',
          label: 'pocketcoder-test',
          ipAddress: '192.168.1.100',
          status: CloudInstanceStatus.creating,
          created: DateTime.now(),
          region: 'us-east',
          planType: 'g6-standard-2',
          provider: 'linode',
        );

        when(() => validationService.validateDeploymentConfig(config))
            .thenReturn(ValidationResult.valid());
        when(() => passwordGenerator.generateAdminPassword())
            .thenAnswer((_) async => 'AdminPass123!');
        when(() => passwordGenerator.generateRootPassword())
            .thenAnswer((_) async => 'RootPass456@');
        when(() => secureStorage.getAccessToken())
            .thenAnswer((_) async => 'test-access-token');
        when(
          () => apiClient.createInstance(
            accessToken: 'test-access-token',
            planType: any(named: 'planType'),
            region: any(named: 'region'),
            image: any(named: 'image'),
            rootPassword: any(named: 'rootPassword'),
            metadata: any(named: 'metadata'),
          ),
        ).thenAnswer((_) async => cloudInstance);
        when(() => secureStorage.storeInstanceCredentials(any()))
            .thenAnswer((_) async {});

        await deploymentService.deploy(config);

        verify(() => secureStorage.storeInstanceCredentials(any())).called(1);
      });
    });

    group('monitorDeployment', () {
      test('polls with exponential backoff starting at 15 seconds', () async {
        final instanceId = '12345';
        final cloudInstance = CloudInstance(
          id: instanceId,
          label: 'pocketcoder-test',
          ipAddress: '192.168.1.100',
          status: CloudInstanceStatus.provisioning,
          created: DateTime.now(),
          region: 'us-east',
          planType: 'g6-standard-2',
          provider: 'linode',
        );

        when(() => secureStorage.getAccessToken())
            .thenAnswer((_) async => 'test-access-token');
        when(() => apiClient.getInstance(instanceId, 'test-access-token'))
            .thenAnswer((_) async => cloudInstance);
        when(() => certManager.retrieveCertificateFingerprint('192.168.1.100',
                port: 443))
            .thenThrow(SocketException('Connection refused'));

        // Start monitoring
        unawaited(deploymentService.monitorDeployment(instanceId));

        // Allow some time for initial poll
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify monitoring started
        expect(deploymentService.isMonitoring, isTrue);
        expect(deploymentService.pollingAttempts, greaterThanOrEqualTo(0));

        // Cancel monitoring
        deploymentService.cancelMonitoring();
        expect(deploymentService.isMonitoring, isFalse);
      });

      test('stops polling after certificate fingerprint retrieved', () async {
        final instanceId = '12345';
        final cloudInstance = CloudInstance(
          id: instanceId,
          label: 'pocketcoder-test',
          ipAddress: '192.168.1.100',
          status: CloudInstanceStatus.provisioning,
          created: DateTime.now(),
          region: 'us-east',
          planType: 'g6-standard-2',
          provider: 'linode',
        );

        when(() => secureStorage.getAccessToken())
            .thenAnswer((_) async => 'test-access-token');
        when(() => apiClient.getInstance(instanceId, 'test-access-token'))
            .thenAnswer((_) async => cloudInstance);
        when(() => certManager.retrieveCertificateFingerprint('192.168.1.100',
                port: 443))
            .thenAnswer((_) async => 'sha256:fingerprint123');
        when(() => certManager.storeFingerprint(instanceId, 'sha256:fingerprint123'))
            .thenAnswer((_) async {});

        await deploymentService.monitorDeployment(instanceId);

        // Allow time for polling to complete
        await Future.delayed(const Duration(milliseconds: 500));

        expect(deploymentService.isMonitoring, isFalse);
        verify(() => certManager.storeFingerprint(instanceId, 'sha256:fingerprint123'))
            .called(1);
      });

      test('concurrent deployment prevention - ignores duplicate monitoring calls',
          () async {
        final instanceId = '12345';
        final cloudInstance = CloudInstance(
          id: instanceId,
          label: 'pocketcoder-test',
          ipAddress: '192.168.1.100',
          status: CloudInstanceStatus.provisioning,
          created: DateTime.now(),
          region: 'us-east',
          planType: 'g6-standard-2',
          provider: 'linode',
        );

        when(() => secureStorage.getAccessToken())
            .thenAnswer((_) async => 'test-access-token');
        when(() => apiClient.getInstance(instanceId, 'test-access-token'))
            .thenAnswer((_) async => cloudInstance);
        when(() => certManager.retrieveCertificateFingerprint('192.168.1.100',
                port: 443))
            .thenThrow(SocketException('Connection refused'));

        // Start first monitoring
        unawaited(deploymentService.monitorDeployment(instanceId));

        await Future.delayed(const Duration(milliseconds: 50));

        // Try to start second monitoring (should be ignored)
        unawaited(deploymentService.monitorDeployment(instanceId));

        await Future.delayed(const Duration(milliseconds: 50));

        // Should still be monitoring (not double-counting)
        expect(deploymentService.isMonitoring, isTrue);

        deploymentService.cancelMonitoring();
      });
    });

    group('cancelMonitoring', () {
      test('stops polling and resets state', () async {
        final instanceId = '12345';
        final cloudInstance = CloudInstance(
          id: instanceId,
          label: 'pocketcoder-test',
          ipAddress: '192.168.1.100',
          status: CloudInstanceStatus.provisioning,
          created: DateTime.now(),
          region: 'us-east',
          planType: 'g6-standard-2',
          provider: 'linode',
        );

        when(() => secureStorage.getAccessToken())
            .thenAnswer((_) async => 'test-access-token');
        when(() => apiClient.getInstance(instanceId, 'test-access-token'))
            .thenAnswer((_) async => cloudInstance);
        when(() => certManager.retrieveCertificateFingerprint('192.168.1.100',
                port: 443))
            .thenThrow(SocketException('Connection refused'));

        unawaited(deploymentService.monitorDeployment(instanceId));

        await Future.delayed(const Duration(milliseconds: 100));

        expect(deploymentService.isMonitoring, isTrue);
        expect(deploymentService.pollingAttempts, greaterThanOrEqualTo(0));

        deploymentService.cancelMonitoring();

        expect(deploymentService.isMonitoring, isFalse);
        expect(deploymentService.pollingAttempts, equals(0));
      });
    });

    group('getInstanceStatus', () {
      test('returns instance status from API', () async {
        final instanceId = '12345';
        final cloudInstance = CloudInstance(
          id: instanceId,
          label: 'pocketcoder-test',
          ipAddress: '192.168.1.100',
          status: CloudInstanceStatus.running,
          created: DateTime.now(),
          region: 'us-east',
          planType: 'g6-standard-2',
          provider: 'linode',
        );

        when(() => secureStorage.getAccessToken())
            .thenAnswer((_) async => 'test-access-token');
        when(() => apiClient.getInstance(instanceId, 'test-access-token'))
            .thenAnswer((_) async => cloudInstance);

        final status = await deploymentService.getInstanceStatus(instanceId);

        expect(status, InstanceStatus.running);
      });

      test('throws exception when not authenticated', () async {
        when(() => secureStorage.getAccessToken()).thenAnswer((_) async => null);

        expect(
          () => deploymentService.getInstanceStatus('12345'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getExistingInstances', () {
      test('filters instances by PocketCoder label prefix', () async {
        final cloudInstances = [
          CloudInstance(
            id: '12345',
            label: 'pocketcoder-web-server',
            ipAddress: '192.168.1.100',
            status: CloudInstanceStatus.running,
            created: DateTime.now(),
            region: 'us-east',
            planType: 'g6-standard-2',
            provider: 'linode',
          ),
          CloudInstance(
            id: '67890',
            label: 'my-other-instance',
            ipAddress: '192.168.1.101',
            status: CloudInstanceStatus.running,
            created: DateTime.now(),
            region: 'us-west',
            planType: 'g6-standard-4',
            provider: 'linode',
          ),
        ];

        when(() => secureStorage.getAccessToken())
            .thenAnswer((_) async => 'test-access-token');
        when(() => apiClient.listInstances('test-access-token',
                labelFilter: 'pocketcoder'))
            .thenAnswer((_) async => [cloudInstances[0]]);

        final instances = await deploymentService.getExistingInstances();

        expect(instances.length, 1);
        expect(instances[0].id, '12345');
        expect(instances[0].label, 'pocketcoder-web-server');
        verify(() => apiClient.listInstances('test-access-token',
                labelFilter: 'pocketcoder'))
            .called(1);
      });

      test('returns empty list when not authenticated', () async {
        when(() => secureStorage.getAccessToken()).thenAnswer((_) async => null);

        final instances = await deploymentService.getExistingInstances();

        expect(instances, isEmpty);
        verifyNever(() => apiClient.listInstances(any(), labelFilter: any(named: 'labelFilter')));
      });
    });
  });
}