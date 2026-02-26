import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/models/deployment_config.dart';
import 'package:pocketcoder_flutter/domain/models/validation_result.dart';
import 'package:pocketcoder_flutter/domain/validation/i_validation_service.dart';

/// Validation service implementation for deployment configuration
@LazySingleton(as: IValidationService)
class ValidationService implements IValidationService {
  // Valid Linode plan types (g6-standard series)
  static const List<String> _validPlanTypes = [
    'g6-standard-1',
    'g6-standard-2',
    'g6-standard-4',
    'g6-standard-6',
    'g6-standard-8',
    'g6-standard-16',
    'g6-standard-32',
  ];

  // Valid Linode regions
  static const List<String> _validRegions = [
    'us-east',
    'us-south',
    'us-west',
    'us-southeast',
    'ca-central',
    'eu-central',
    'eu-west',
    'eu-north',
    'ap-northeast',
    'ap-south',
    'ap-southeast',
    'us-iad',
    'us-ord',
    'us-sea',
  ];

  // Gemini API key prefix
  static const String _geminiApiKeyPrefix = 'AIza';

  @override
  ValidationResult validateEmail(String email) {
    if (email.isEmpty) {
      return ValidationResult.invalid('Please enter a valid email address');
    }

    // RFC 5322 simplified email regex
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}"
      r'[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return ValidationResult.invalid('Please enter a valid email address');
    }

    return ValidationResult.valid();
  }

  @override
  ValidationResult validateGeminiApiKey(String apiKey) {
    if (apiKey.isEmpty) {
      return ValidationResult.invalid(
        'Gemini API key is required and must start with "$_geminiApiKeyPrefix"',
      );
    }

    if (!apiKey.startsWith(_geminiApiKeyPrefix)) {
      return ValidationResult.invalid(
        'Gemini API key is required and must start with "$_geminiApiKeyPrefix"',
      );
    }

    return ValidationResult.valid();
  }

  @override
  ValidationResult validatePlanType(String planType) {
    if (planType.isEmpty) {
      return ValidationResult.invalid('Please select a valid Linode plan');
    }

    if (!_validPlanTypes.contains(planType)) {
      return ValidationResult.invalid('Please select a valid Linode plan');
    }

    return ValidationResult.valid();
  }

  @override
  ValidationResult validateRegion(String region) {
    if (region.isEmpty) {
      return ValidationResult.invalid('Please select a valid region');
    }

    if (!_validRegions.contains(region)) {
      return ValidationResult.invalid('Please select a valid region');
    }

    return ValidationResult.valid();
  }

  @override
  ValidationResult validateDeploymentConfig(DeploymentConfig config) {
    final fieldErrors = <String, String>{};

    final emailResult = validateEmail(config.adminEmail);
    if (!emailResult.isValid) {
      fieldErrors['email'] = emailResult.errorMessage!;
    }

    final apiKeyResult = validateGeminiApiKey(config.geminiApiKey);
    if (!apiKeyResult.isValid) {
      fieldErrors['geminiApiKey'] = apiKeyResult.errorMessage!;
    }

    final planResult = validatePlanType(config.planType);
    if (!planResult.isValid) {
      fieldErrors['planType'] = planResult.errorMessage!;
    }

    final regionResult = validateRegion(config.region);
    if (!regionResult.isValid) {
      fieldErrors['region'] = regionResult.errorMessage!;
    }

    if (fieldErrors.isNotEmpty) {
      return ValidationResult.withFieldErrors(fieldErrors);
    }

    return ValidationResult.valid();
  }
}