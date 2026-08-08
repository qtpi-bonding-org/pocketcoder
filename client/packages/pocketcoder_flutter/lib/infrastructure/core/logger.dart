import 'package:flutter/foundation.dart';

/// Simple logging service for the application.
///
/// In production, this could be replaced with a more sophisticated
/// logging solution like logger or talker.
class AppLogger {
  static const String _tag = 'PocketCoder';

  static void debug(String message, [Map<String, Object?>? data]) {
    if (kDebugMode) {
      _print('DEBUG', message, redact(data));
    }
  }

  static void info(String message, [Map<String, Object?>? data]) {
    _print('INFO', message, redact(data));
  }

  static void warning(String message, [Map<String, Object?>? data]) {
    _print('WARN', message, redact(data));
  }

  static void error(String message, [dynamic error, StackTrace? stack]) {
    // Exception messages may contain response bodies, credentials, or user
    // input. Keep the diagnostic record in Privserver; console logging only
    // exposes the controlled label and exception type.
    final errorType = error?.runtimeType.toString();
    _print('ERROR', message, errorType);
    if (stack != null) {
      _print('STACK', '', stack);
    }
  }

  static Map<String, Object?>? redact(Map<String, Object?>? data) {
    if (data == null) return null;
    const secretKeys = {'password', 'token', 'secret', 'authorization', 'cookie'};
    final result = <String, Object?>{};
    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value?.toString() ?? '';
      result[entry.key] = secretKeys.any(key.contains)
          ? '[REDACTED]'
          : value.replaceAllMapped(
              RegExp(r'(code|token|password|secret)=([^&\s]+)', caseSensitive: false),
              (match) => '${match.group(1)}=[REDACTED]',
            );
    }
    return result;
  }

  static void _print(String level, String message, [dynamic data]) {
    final timestamp = DateTime.now().toIso8601String();
    final dataStr = data != null ? ' | $data' : '';
    debugPrint('[$timestamp] [$_tag] [$level] $message$dataStr');
  }
}

/// Extension methods for easy logging in classes.
extension LoggerExtension on Object {
  void logDebug(String message, [Map<String, Object?>? data]) =>
      AppLogger.debug(message, data);
  void logInfo(String message, [Map<String, Object?>? data]) => AppLogger.info(message, data);
  void logWarning(String message, [Map<String, Object?>? data]) =>
      AppLogger.warning(message, data);
  void logError(String message, [dynamic error, StackTrace? stack]) =>
      AppLogger.error(message, error, stack);
}
