import 'package:freezed_annotation/freezed_annotation.dart';

part 'validation_result.freezed.dart';
part 'validation_result.g.dart';

@freezed
class ValidationResult with _$ValidationResult {
  const factory ValidationResult({
    required bool isValid,
    String? errorMessage,
    Map<String, String>? fieldErrors,
  }) = _ValidationResult;

  factory ValidationResult.valid() =>
      const ValidationResult(isValid: true);

  factory ValidationResult.invalid(String errorMessage) =>
      ValidationResult(isValid: false, errorMessage: errorMessage);

  factory ValidationResult.withFieldErrors(Map<String, String> fieldErrors) =>
      ValidationResult(isValid: false, fieldErrors: fieldErrors);

  factory ValidationResult.fromJson(Map<String, dynamic> json) =>
      _$ValidationResultFromJson(json);
}