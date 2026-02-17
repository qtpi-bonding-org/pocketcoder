import 'package:flutter/foundation.dart';

/// Simple logging service for the application.
///
/// In production, this could be replaced with a more sophisticated
/// logging solution like logger or talker.
class AppLogger {
  static const String _tag = 'PocketCoder';

  static void debug(String message, [dynamic data]) {
    if (kDebugMode) {
      _print('DEBUG', message, data);
    }
  }

  static void info(String message, [dynamic data]) {
    _print('INFO', message, data);
  }

  static void warning(String message, [dynamic data]) {
    _print('WARN', message, data);
  }

  static void error(String message, [dynamic error, StackTrace? stack]) {
    _print('ERROR', message, error);
    if (stack != null) {
      _print('STACK', '', stack);
    }
  }

  static void _print(String level, String message, [dynamic data]) {
    final timestamp = DateTime.now().toIso8601String();
    final dataStr = data != null ? ' | $data' : '';
    print('[$timestamp] [$_tag] [$level] $message$dataStr');
  }
}

/// Extension methods for easy logging in classes.
extension LoggerExtension on Object {
  void logDebug(String message, [dynamic data]) => AppLogger.debug(message, data);
  void logInfo(String message, [dynamic data]) => AppLogger.info(message, data);
  void logWarning(String message, [dynamic data]) => AppLogger.warning(message, data);
  void logError(String message, [dynamic error, StackTrace? stack]) =>
      AppLogger.error(message, error, stack);
}