import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/models/deployment_config.dart';
import 'package:pocketcoder_flutter/infrastructure/validation/validation_service.dart';

void main() {
  group('ValidationService', () {
    late ValidationService validationService;

    setUp(() {
      validationService = ValidationService();
    });

    group('validateEmail', () {
      test('validates correct email format', () {
        final result = validationService.validateEmail('user@example.com');
        expect(result.isValid, isTrue);
        expect(result.errorMessage, isNull);
      });

      test('validates email with subdomain', () {
        final result = validationService.validateEmail('user@mail.example.com');
        expect(result.isValid, isTrue);
      });

      test('validates email with plus addressing', () {
        final result = validationService.validateEmail('user+tag@example.com');
        expect(result.isValid, isTrue);
      });

      test('rejects empty email', () {
        final result = validationService.validateEmail('');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('email'));
      });

      test('rejects email without @ symbol', () {
        final result = validationService.validateEmail('userexample.com');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('email'));
      });

      test('rejects email without domain', () {
        final result = validationService.validateEmail('user@');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('email'));
      });

      test('rejects email without username', () {
        final result = validationService.validateEmail('@example.com');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('email'));
      });
    });

    group('validateGeminiApiKey', () {
      test('validates correct Gemini API key with AIza prefix', () {
        final result = validationService.validateGeminiApiKey('AIzaSyTestKey123456');
        expect(result.isValid, isTrue);
      });

      test('rejects empty API key', () {
        final result = validationService.validateGeminiApiKey('');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('AIza'));
      });

      test('rejects API key without AIza prefix', () {
        final result = validationService.validateGeminiApiKey('TestKeyWithoutPrefix');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('AIza'));
      });

      test('rejects API key with lowercase aiza prefix', () {
        final result = validationService.validateGeminiApiKey('aizaTestKey');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('AIza'));
      });
    });

    group('validatePlanType', () {
      test('validates correct plan type g6-standard-2', () {
        final result = validationService.validatePlanType('g6-standard-2');
        expect(result.isValid, isTrue);
      });

      test('validates correct plan type g6-standard-4', () {
        final result = validationService.validatePlanType('g6-standard-4');
        expect(result.isValid, isTrue);
      });

      test('validates correct plan type g6-standard-8', () {
        final result = validationService.validatePlanType('g6-standard-8');
        expect(result.isValid, isTrue);
      });

      test('rejects empty plan type', () {
        final result = validationService.validatePlanType('');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('plan'));
      });

      test('rejects invalid plan type', () {
        final result = validationService.validatePlanType('invalid-plan-type');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('plan'));
      });

      test('rejects plan type with wrong prefix', () {
        final result = validationService.validatePlanType('g5-standard-2');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('plan'));
      });
    });

    group('validateRegion', () {
      test('validates correct region us-east', () {
        final result = validationService.validateRegion('us-east');
        expect(result.isValid, isTrue);
      });

      test('validates correct region us-west', () {
        final result = validationService.validateRegion('us-west');
        expect(result.isValid, isTrue);
      });

      test('validates correct region eu-central', () {
        final result = validationService.validateRegion('eu-central');
        expect(result.isValid, isTrue);
      });

      test('validates correct region us-iad', () {
        final result = validationService.validateRegion('us-iad');
        expect(result.isValid, isTrue);
      });

      test('rejects empty region', () {
        final result = validationService.validateRegion('');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('region'));
      });

      test('rejects invalid region', () {
        final result = validationService.validateRegion('invalid-region');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('region'));
      });
    });

    group('validateDeploymentConfig', () {
      test('validates correct deployment configuration', () {
        final config = DeploymentConfig(
          planType: 'g6-standard-2',
          region: 'us-east',
          adminEmail: 'admin@example.com',
          geminiApiKey: 'AIzaTestKey123',
          ntfyEnabled: true,
          cloudInitTemplateUrl: 'https://example.com/cloud-init',
        );
        final result = validationService.validateDeploymentConfig(config);
        expect(result.isValid, isTrue);
        expect(result.fieldErrors, isNull);
      });

      test('returns field errors for invalid email', () {
        final config = DeploymentConfig(
          planType: 'g6-standard-2',
          region: 'us-east',
          adminEmail: 'invalid-email',
          geminiApiKey: 'AIzaTestKey123',
          ntfyEnabled: true,
          cloudInitTemplateUrl: 'https://example.com/cloud-init',
        );
        final result = validationService.validateDeploymentConfig(config);
        expect(result.isValid, isFalse);
        expect(result.fieldErrors, isNotNull);
        expect(result.fieldErrors!.containsKey('email'), isTrue);
      });

      test('returns field errors for invalid API key', () {
        final config = DeploymentConfig(
          planType: 'g6-standard-2',
          region: 'us-east',
          adminEmail: 'admin@example.com',
          geminiApiKey: 'InvalidKey',
          ntfyEnabled: true,
          cloudInitTemplateUrl: 'https://example.com/cloud-init',
        );
        final result = validationService.validateDeploymentConfig(config);
        expect(result.isValid, isFalse);
        expect(result.fieldErrors, isNotNull);
        expect(result.fieldErrors!.containsKey('geminiApiKey'), isTrue);
      });

      test('returns field errors for invalid plan type', () {
        final config = DeploymentConfig(
          planType: 'invalid-plan',
          region: 'us-east',
          adminEmail: 'admin@example.com',
          geminiApiKey: 'AIzaTestKey123',
          ntfyEnabled: true,
          cloudInitTemplateUrl: 'https://example.com/cloud-init',
        );
        final result = validationService.validateDeploymentConfig(config);
        expect(result.isValid, isFalse);
        expect(result.fieldErrors, isNotNull);
        expect(result.fieldErrors!.containsKey('planType'), isTrue);
      });

      test('returns field errors for invalid region', () {
        final config = DeploymentConfig(
          planType: 'g6-standard-2',
          region: 'invalid-region',
          adminEmail: 'admin@example.com',
          geminiApiKey: 'AIzaTestKey123',
          ntfyEnabled: true,
          cloudInitTemplateUrl: 'https://example.com/cloud-init',
        );
        final result = validationService.validateDeploymentConfig(config);
        expect(result.isValid, isFalse);
        expect(result.fieldErrors, isNotNull);
        expect(result.fieldErrors!.containsKey('region'), isTrue);
      });

      test('returns multiple field errors for multiple invalid fields', () {
        final config = DeploymentConfig(
          planType: 'invalid-plan',
          region: 'invalid-region',
          adminEmail: 'invalid-email',
          geminiApiKey: 'InvalidKey',
          ntfyEnabled: true,
          cloudInitTemplateUrl: 'https://example.com/cloud-init',
        );
        final result = validationService.validateDeploymentConfig(config);
        expect(result.isValid, isFalse);
        expect(result.fieldErrors, isNotNull);
        expect(result.fieldErrors!.length, equals(4));
        expect(result.fieldErrors!.containsKey('email'), isTrue);
        expect(result.fieldErrors!.containsKey('geminiApiKey'), isTrue);
        expect(result.fieldErrors!.containsKey('planType'), isTrue);
        expect(result.fieldErrors!.containsKey('region'), isTrue);
      });
    });
  });
}