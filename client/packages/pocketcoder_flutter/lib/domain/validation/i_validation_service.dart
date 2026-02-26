import 'package:pocketcoder_flutter/domain/models/deployment_config.dart';
import 'package:pocketcoder_flutter/domain/models/validation_result.dart';

/// Abstract interface for input validation
abstract class IValidationService {
  /// Validates email format
  ValidationResult validateEmail(String email);

  /// Validates Gemini API key
  ValidationResult validateGeminiApiKey(String apiKey);

  /// Validates plan type
  ValidationResult validatePlanType(String planType);

  /// Validates region
  ValidationResult validateRegion(String region);

  /// Validates deployment configuration
  ValidationResult validateDeploymentConfig(DeploymentConfig config);
}