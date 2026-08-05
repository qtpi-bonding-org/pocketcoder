import 'package:flutter/foundation.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';

/// Captures only the structured fields supported by the pinned Privserver
/// package. The in-memory queue covers failures that happen before bootstrap
/// configures Privserver.
class PocketCoderDiagnosticCapture {
  PocketCoderDiagnosticCapture({
    ErrorPrivserverConfig? Function()? configReader,
    int maxPending = 20,
  })  : _configReader = configReader ?? (() => ErrorPrivserverMixin.config),
        _maxPending = maxPending < 1 ? 1 : maxPending;

  final ErrorPrivserverConfig? Function() _configReader;
  final int _maxPending;
  final List<_PendingDiagnostic> _pending = <_PendingDiagnostic>[];

  int get pendingCount => _pending.length;

  /// Records a safe diagnostic without ever affecting the caller.
  ///
  /// [source] and [operation] must be static developer-controlled labels.
  /// Exception messages and arbitrary payloads are intentionally not accepted.
  Future<void> capture({
    required Object error,
    StackTrace? stackTrace,
    required String source,
    String? operation,
    String? errorCode,
  }) async {
    final pending = _PendingDiagnostic(
      error: error,
      stackTrace: stackTrace,
      source: _source(source, operation),
      errorCode: errorCode,
    );
    ErrorPrivserverConfig? config;
    try {
      config = _configReader();
    } catch (_) {
      config = null;
    }
    if (config == null) {
      if (_pending.length >= _maxPending) {
        _pending.removeAt(0);
      }
      _pending.add(pending);
      return;
    }
    await _save(config, pending);
  }

  /// Flushes the bounded bootstrap queue after Privserver is configured.
  Future<void> flush() async {
    ErrorPrivserverConfig? config;
    try {
      config = _configReader();
    } catch (_) {
      return;
    }
    if (config == null || _pending.isEmpty) return;

    final pending = List<_PendingDiagnostic>.of(_pending);
    _pending.clear();
    for (final item in pending) {
      await _save(config, item);
    }
  }

  Future<void> _save(
    ErrorPrivserverConfig config,
    _PendingDiagnostic pending,
  ) async {
    try {
      final userMessage = config.exceptionMapper(pending.error)?.key;
      final entry = ErrorEntry(
        source: pending.source,
        errorType: pending.error.runtimeType.toString(),
        errorCode: pending.errorCode ?? config.errorCodeMapper(pending.error),
        stackTrace:
            pending.stackTrace?.toString() ?? 'No stack trace available',
        timestamp: DateTime.now(),
        userMessage: userMessage,
      );
      await config.storage.saveError(entry);
    } catch (captureError, captureStack) {
      // Diagnostics must never become a second application failure.
      debugPrint('PocketCoder diagnostic capture failed: $captureError');
      debugPrint('$captureStack');
    }
  }

  static String _source(String source, String? operation) {
    if (operation == null || operation.isEmpty) return source;
    return '$source.$operation';
  }
}

final PocketCoderDiagnosticCapture pocketCoderDiagnosticCapture =
    PocketCoderDiagnosticCapture();

bool _globalHandlersInstalled = false;

/// Installs the two Flutter-level uncaught error bridges available without
/// wrapping every application entrypoint in a custom zone.
void installPocketCoderGlobalErrorHandlers({
  PocketCoderDiagnosticCapture? capture,
}) {
  if (_globalHandlersInstalled) return;
  _globalHandlersInstalled = true;
  final diagnosticCapture = capture ?? pocketCoderDiagnosticCapture;

  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    handlePocketCoderFlutterError(
      details,
      capture: diagnosticCapture,
      previous: previousFlutterError,
    );
  };

  final previousAsyncError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    return handlePocketCoderAsyncError(
      error,
      stack,
      capture: diagnosticCapture,
      previous: previousAsyncError,
    );
  };
}

/// Testable framework-error bridge used by the installed handler above.
void handlePocketCoderFlutterError(
  FlutterErrorDetails details, {
  required PocketCoderDiagnosticCapture capture,
  FlutterExceptionHandler? previous,
}) {
  capture.capture(
    error: details.exception,
    stackTrace: details.stack,
    source: 'Flutter.framework',
  );
  previous?.call(details);
}

/// Testable uncaught-async bridge used by the installed handler above.
bool handlePocketCoderAsyncError(
  Object error,
  StackTrace stack, {
  required PocketCoderDiagnosticCapture capture,
  bool Function(Object, StackTrace)? previous,
}) {
  capture.capture(
    error: error,
    stackTrace: stack,
    source: 'Flutter.async',
  );
  return previous?.call(error, stack) ?? false;
}

class _PendingDiagnostic {
  const _PendingDiagnostic({
    required this.error,
    required this.stackTrace,
    required this.source,
    required this.errorCode,
  });

  final Object error;
  final StackTrace? stackTrace;
  final String source;
  final String? errorCode;
}
