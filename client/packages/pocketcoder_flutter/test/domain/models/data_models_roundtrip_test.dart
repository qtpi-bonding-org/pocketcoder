import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/models/oauth_token.dart';
import 'package:pocketcoder_flutter/domain/models/deployment_config.dart';
import 'package:pocketcoder_flutter/domain/models/instance.dart';
import 'package:pocketcoder_flutter/domain/models/instance_credentials.dart';
import 'package:pocketcoder_flutter/domain/models/validation_result.dart';
import 'package:pocketcoder_flutter/domain/models/cloud_provider.dart';
import 'package:pocketcoder_flutter/domain/models/app_config.dart';

void main() {
  group('Data Models Round-Trip', () {
    group('OAuthToken', () {
      test('OAuthToken serializes and deserializes correctly', () {
        final token = OAuthToken(
          accessToken: 'access_123',
          refreshToken: 'refresh_456',
          expiresAt: DateTime(2025, 1, 1, 12, 0, 0),
          scopes: ['linodes:read_write', 'linodes:create'],
        );

        final json = token.toJson();
        final restored = OAuthToken.fromJson(json);

        expect(restored.accessToken, token.accessToken);
        expect(restored.refreshToken, token.refreshToken);
        expect(restored.expiresAt, token.expiresAt);
        expect(restored.scopes, token.scopes);
      });

      test('OAuthToken isExpired returns correct value', () {
        final expiredToken = OAuthToken(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime(2020, 1, 1),
          scopes: [],
        );

        final validToken = OAuthToken(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime(2099, 1, 1),
          scopes: [],
        );

        expect(expiredToken.isExpired, isTrue);
        expect(validToken.isExpired, isFalse);
      });

      test('OAuthToken needsRefresh returns correct value', () {
        final needsRefresh = OAuthToken(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(minutes: 3)),
          scopes: [],
        );

        final doesNotNeedRefresh = OAuthToken(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          scopes: [],
        );

        expect(needsRefresh.needsRefresh, isTrue);
        expect(doesNotNeedRefresh.needsRefresh, isFalse);
      });
    });

    group('DeploymentConfig', () {
      test('DeploymentConfig serializes and deserializes correctly', () {
        final config = DeploymentConfig(
          planType: 'g6-standard-2',
          region: 'us-east',
          adminEmail: 'admin@example.com',
          geminiApiKey: 'AIza_test_key',
          linodeToken: 'optional_token',
          ntfyEnabled: true,
          cloudInitTemplateUrl: 'https://example.com/cloud-init',
        );

        final json = config.toJson();
        final restored = DeploymentConfig.fromJson(json);

        expect(restored.planType, config.planType);
        expect(restored.region, config.region);
        expect(restored.adminEmail, config.adminEmail);
        expect(restored.geminiApiKey, config.geminiApiKey);
        expect(restored.linodeToken, config.linodeToken);
        expect(restored.ntfyEnabled, config.ntfyEnabled);
        expect(restored.cloudInitTemplateUrl, config.cloudInitTemplateUrl);
      });

      test('DeploymentConfig toMetadata returns correct map', () {
        final config = DeploymentConfig(
          planType: 'g6-standard-2',
          region: 'us-east',
          adminEmail: 'admin@example.com',
          geminiApiKey: 'AIza_test_key',
          linodeToken: null,
          ntfyEnabled: true,
          cloudInitTemplateUrl: 'https://example.com/cloud-init',
        );

        final metadata = config.toMetadata();

        expect(metadata['admin_email'], 'admin@example.com');
        expect(metadata['gemini_api_key'], 'AIza_test_key');
        expect(metadata['ntfy_enabled'], 'true');
        expect(metadata.containsKey('linode_token'), isFalse);
      });

      test('DeploymentConfig toMetadata includes optional linodeToken', () {
        final config = DeploymentConfig(
          planType: 'g6-standard-2',
          region: 'us-east',
          adminEmail: 'admin@example.com',
          geminiApiKey: 'AIza_test_key',
          linodeToken: 'secret_token',
          ntfyEnabled: false,
          cloudInitTemplateUrl: 'https://example.com/cloud-init',
        );

        final metadata = config.toMetadata();

        expect(metadata['linode_token'], 'secret_token');
      });
    });

    group('Instance', () {
      test('Instance serializes and deserializes correctly', () {
        final instance = Instance(
          id: 'instance-123',
          label: 'pocketcoder-12345',
          ipAddress: '192.168.1.100',
          status: InstanceStatus.running,
          created: DateTime(2025, 1, 1, 10, 0, 0),
          region: 'us-east',
          planType: 'g6-standard-2',
          provider: 'linode',
          adminEmail: 'admin@example.com',
        );

        final json = instance.toJson();
        final restored = Instance.fromJson(json);

        expect(restored.id, instance.id);
        expect(restored.label, instance.label);
        expect(restored.ipAddress, instance.ipAddress);
        expect(restored.status, instance.status);
        expect(restored.created, instance.created);
        expect(restored.region, instance.region);
        expect(restored.planType, instance.planType);
        expect(restored.provider, instance.provider);
        expect(restored.adminEmail, instance.adminEmail);
      });

      test('Instance httpsUrl returns correct URL', () {
        final instance = Instance(
          id: 'instance-123',
          label: 'pocketcoder',
          ipAddress: '192.168.1.100',
          status: InstanceStatus.running,
          created: DateTime.now(),
          region: 'us-east',
          planType: 'g6-standard-2',
          provider: 'linode',
        );

        expect(instance.httpsUrl, 'https://192.168.1.100');
      });
    });

    group('InstanceCredentials', () {
      test('InstanceCredentials serializes and deserializes correctly', () {
        final credentials = InstanceCredentials(
          instanceId: 'instance-123',
          adminPassword: 'AdminPass123!',
          rootPassword: 'RootPass456@',
          adminEmail: 'admin@example.com',
        );

        final json = credentials.toJson();
        final restored = InstanceCredentials.fromJson(json);

        expect(restored.instanceId, credentials.instanceId);
        expect(restored.adminPassword, credentials.adminPassword);
        expect(restored.rootPassword, credentials.rootPassword);
        expect(restored.adminEmail, credentials.adminEmail);
      });
    });

    group('ValidationResult', () {
      test('ValidationResult.valid() creates valid result', () {
        final result = ValidationResult.valid();

        expect(result.isValid, isTrue);
        expect(result.errorMessage, isNull);
        expect(result.fieldErrors, isNull);
      });

      test('ValidationResult.invalid() creates invalid result', () {
        final result = ValidationResult.invalid('Test error');

        expect(result.isValid, isFalse);
        expect(result.errorMessage, 'Test error');
        expect(result.fieldErrors, isNull);
      });

      test('ValidationResult.withFieldErrors() creates result with field errors', () {
        final fieldErrors = {
          'email': 'Invalid email format',
          'apiKey': 'API key is required',
        };
        final result = ValidationResult.withFieldErrors(fieldErrors);

        expect(result.isValid, isFalse);
        expect(result.fieldErrors, fieldErrors);
        expect(result.fieldErrors!['email'], 'Invalid email format');
        expect(result.fieldErrors!['apiKey'], 'API key is required');
      });

      test('ValidationResult serializes and deserializes correctly', () {
        final result = ValidationResult.invalid('Test error');

        final json = result.toJson();
        final restored = ValidationResult.fromJson(json);

        expect(restored.isValid, result.isValid);
        expect(restored.errorMessage, result.errorMessage);
      });
    });

    group('CloudProvider Models', () {
      test('CloudInstance serializes and deserializes correctly', () {
        final instance = CloudInstance(
          id: '12345',
          label: 'pocketcoder-test',
          ipAddress: '10.0.0.5',
          status: CloudInstanceStatus.running,
          created: DateTime(2025, 1, 1),
          region: 'us-east',
          planType: 'g6-standard-2',
          provider: 'linode',
        );

        final json = instance.toJson();
        final restored = CloudInstance.fromJson(json);

        expect(restored.id, instance.id);
        expect(restored.label, instance.label);
        expect(restored.ipAddress, instance.ipAddress);
        expect(restored.status, instance.status);
        expect(restored.created, instance.created);
        expect(restored.region, instance.region);
        expect(restored.planType, instance.planType);
        expect(restored.provider, instance.provider);
      });

      test('InstancePlan serializes and deserializes correctly', () {
        final plan = InstancePlan(
          id: 'g6-standard-2',
          name: 'Linode 4GB',
          memoryMB: 4096,
          vcpus: 2,
          diskGB: 48,
          monthlyPriceUSD: 24.00,
          recommended: true,
        );

        final json = plan.toJson();
        final restored = InstancePlan.fromJson(json);

        expect(restored.id, plan.id);
        expect(restored.name, plan.name);
        expect(restored.memoryMB, plan.memoryMB);
        expect(restored.vcpus, plan.vcpus);
        expect(restored.diskGB, plan.diskGB);
        expect(restored.monthlyPriceUSD, plan.monthlyPriceUSD);
        expect(restored.recommended, plan.recommended);
      });

      test('Region serializes and deserializes correctly', () {
        final region = Region(
          id: 'us-east',
          name: 'Newark, NJ',
          country: 'US',
          city: 'Newark',
        );

        final json = region.toJson();
        final restored = Region.fromJson(json);

        expect(restored.id, region.id);
        expect(restored.name, region.name);
        expect(restored.country, region.country);
        expect(restored.city, region.city);
      });
    });

    group('AppConfig', () {
      test('AppConfig serializes and deserializes correctly', () {
        final config = AppConfig(
          linodeClientId: 'test_client_id',
          linodeRedirectUri: 'pocketcoder://oauth-callback',
          cloudInitTemplateUrl: 'https://example.com/cloud-init',
          maxPollingAttempts: 20,
          initialPollingIntervalSeconds: 15,
        );

        final json = config.toJson();
        final restored = AppConfig.fromJson(json);

        expect(restored.linodeClientId, config.linodeClientId);
        expect(restored.linodeRedirectUri, config.linodeRedirectUri);
        expect(restored.cloudInitTemplateUrl, config.cloudInitTemplateUrl);
        expect(restored.maxPollingAttempts, config.maxPollingAttempts);
        expect(restored.initialPollingIntervalSeconds, config.initialPollingIntervalSeconds);
      });

      test('AppConfig constants have expected values', () {
        expect(AppConfig.kLinodeRedirectUri, 'pocketcoder://oauth-callback');
        expect(AppConfig.kMaxPollingAttempts, 20);
        expect(AppConfig.kInitialPollingIntervalSeconds, 15);
      });
    });
  });
}