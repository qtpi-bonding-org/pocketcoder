import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';

/// Structured, non-sensitive logging for the first-launch funnel.
///
/// Never pass passwords, authorization codes, access tokens, refresh tokens,
/// or full request bodies to this logger.
abstract final class OnboardingLogger {
  static void event(String message, [Map<String, Object?> details = const {}]) {
    AppLogger.debug('[Onboarding] $message', _safeDetails(details));
  }

  static void failure(
    String message,
    Object error,
    StackTrace stackTrace, [
    Map<String, Object?> details = const {},
  ]) {
    AppLogger.error('[Onboarding] $message', error, stackTrace);
  }

  static Map<String, Object?> _safeDetails(Map<String, Object?> details) {
    return details.map((key, value) {
      final sensitive = key.toLowerCase().contains('error') ||
          key.toLowerCase().contains('password') ||
          key.toLowerCase().contains('token') ||
          key.toLowerCase().contains('secret');
      return MapEntry(
        key,
        sensitive && value != null ? value.runtimeType.toString() : value,
      );
    });
  }
}
