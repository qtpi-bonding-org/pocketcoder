import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';

/// Structured, non-sensitive logging for the first-launch funnel.
///
/// Never pass passwords, authorization codes, access tokens, refresh tokens,
/// or full request bodies to this logger.
abstract final class OnboardingLogger {
  static void event(String message, [Map<String, Object?> details = const {}]) {
    AppLogger.debug('[Onboarding] $message', details);
  }

  static void failure(
    String message,
    Object error,
    StackTrace stackTrace, [
    Map<String, Object?> details = const {},
  ]) {
    AppLogger.error('[Onboarding] $message', error, stackTrace);
  }
}
