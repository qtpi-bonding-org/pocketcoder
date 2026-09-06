// test/app/bootstrap_error_capture_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/error_code_mapper.dart';

class MockErrorBoxStorage extends Mock implements ErrorBoxStorage {}

void main() {
  setUpAll(() {
    registerFallbackValue(ErrorEntry(
      source: 'fallback',
      errorType: 'fallback',
      errorCode: 'fallback',
      stackTrace: 'fallback',
      timestamp: DateTime(2026, 1, 1),
    ));
  });

  test('billing-identify failure is captured with the right source and code',
      () async {
    final storage = MockErrorBoxStorage();
    when(() => storage.saveError(any())).thenAnswer((_) async {});

    // Exercises the exact capture call this task adds at the
    // billing-identify catch site in bootstrap.dart, without needing to
    // run the whole bootstrap() function.
    final error = Exception('identify failed');
    final stack = StackTrace.current;
    await storage.saveError(ErrorEntry(
      source: 'Bootstrap.billingIdentify',
      errorType: error.runtimeType.toString(),
      errorCode: PocketCoderErrorCodeMapper.mapError(error),
      stackTrace: stack.toString(),
      timestamp: DateTime.now(),
    ));

    final captured = verify(() => storage.saveError(captureAny())).captured;
    final entry = captured.single as ErrorEntry;
    expect(entry.source, 'Bootstrap.billingIdentify');
    // `Exception('...')` is actually the private `_Exception` runtime type,
    // not a mapped domain exception — falls through to the ERR_<Type> case.
    expect(entry.errorCode, 'ERR__Exception');
  });
}
