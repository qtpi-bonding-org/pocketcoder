import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_report.dart';

class _MockStorage extends Mock implements ErrorBoxStorage {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      ErrorEntry(
        source: 'fallback',
        errorType: 'fallback',
        errorCode: 'fallback',
        stackTrace: 'fallback',
        timestamp: DateTime(2026),
      ),
    );
  });

  late _MockStorage storage;
  late ErrorPrivserverConfig config;

  setUp(() {
    storage = _MockStorage();
    config = ErrorPrivserverConfig(
      storage: storage,
      reporter: (_) async => false,
      errorCodeMapper: (_) => 'ERR_TEST',
      exceptionMapper: (_) => const MessageKey.error('error.generic'),
    );
  });

  test('captures only Privserver fields and preserves the stack', () async {
    when(() => storage.saveError(any())).thenAnswer((_) async {});
    final capture = PocketCoderDiagnosticCapture(configReader: () => config);
    final error = Exception('do not capture this message');
    final stack = StackTrace.fromString('#0 controlled stack');

    await capture.capture(
      error: error,
      stackTrace: stack,
      source: 'ChatCubit',
      operation: 'send',
    );

    final entry = verify(() => storage.saveError(captureAny())).captured.single
        as ErrorEntry;
    expect(entry.source, 'ChatCubit.send');
    expect(entry.errorType, '_Exception');
    expect(entry.errorCode, 'ERR_TEST');
    expect(entry.stackTrace, '#0 controlled stack');
    expect(entry.userMessage, 'error.generic');
    expect(entry.stackTrace, isNot(contains('do not capture')));
  });

  test('queues before configuration and flushes after configuration', () async {
    when(() => storage.saveError(any())).thenAnswer((_) async {});
    ErrorPrivserverConfig? currentConfig;
    final capture = PocketCoderDiagnosticCapture(
      configReader: () => currentConfig,
      maxPending: 1,
    );

    await capture.capture(
      error: StateError('bootstrap detail'),
      source: 'Bootstrap',
    );
    expect(capture.pendingCount, 1);
    verifyNever(() => storage.saveError(any()));

    currentConfig = config;
    await capture.flush();

    expect(capture.pendingCount, 0);
    verify(() => storage.saveError(any())).called(1);
  });

  test('capture does not throw when Privserver is unavailable', () async {
    final capture = PocketCoderDiagnosticCapture(configReader: () => null);

    await expectLater(
      capture.capture(
        error: StateError('not persisted'),
        source: 'Flutter.async',
      ),
      completes,
    );
  });

  test('framework and async bridges reach the adapter', () async {
    when(() => storage.saveError(any())).thenAnswer((_) async {});
    final capture = PocketCoderDiagnosticCapture(configReader: () => config);
    var frameworkForwarded = false;
    var asyncForwarded = false;
    final stack = StackTrace.fromString('#0 bridge stack');

    handlePocketCoderFlutterError(
      FlutterErrorDetails(
        exception: StateError('framework failure'),
        stack: stack,
      ),
      capture: capture,
      previous: (_) => frameworkForwarded = true,
    );
    final handled = handlePocketCoderAsyncError(
      StateError('async failure'),
      stack,
      capture: capture,
      previous: (_, __) {
        asyncForwarded = true;
        return true;
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(frameworkForwarded, isTrue);
    expect(asyncForwarded, isTrue);
    expect(handled, isTrue);
    final entries = verify(() => storage.saveError(captureAny()))
        .captured
        .cast<ErrorEntry>();
    expect(entries.map((entry) => entry.source), contains('Flutter.framework'));
    expect(entries.map((entry) => entry.source), contains('Flutter.async'));
  });

  test('diagnostic report contains only the approved fields', () {
    final report = DiagnosticReportFormatter.format(
      ErrorEntry(
        source: 'AuthCubit.login',
        errorType: 'AuthException',
        errorCode: 'AUTH_001',
        stackTrace: '#0 safe stack',
        timestamp: DateTime.utc(2026, 1, 2, 3, 4),
        userMessage: 'Authentication failed',
      ),
    );

    expect(report, contains('AuthCubit.login'));
    expect(report, contains('AUTH_001'));
    expect(report, contains('Authentication failed'));
    expect(report, contains('#0 safe stack'));
    expect(report, isNot(contains('prompt')));
    expect(report, isNot(contains('token')));
  });
}
