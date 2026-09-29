import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/app/optional_startup_step.dart';

void main() {
  test(
      'gives up on a step that never completes -- startup steps run before '
      'runApp(), so a hang would leave only the native splash', () async {
    final stopwatch = Stopwatch()..start();

    await runOptionalStartupStep(
      'neverCompletes',
      () => Completer<void>().future,
      timeout: const Duration(milliseconds: 100),
    );

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('does not let a failing optional step abort startup', () async {
    await expectLater(
      runOptionalStartupStep(
        'throws',
        () async => throw StateError('plugin unavailable'),
      ),
      completes,
    );
  });

  test('runs the step to completion when it finishes in time', () async {
    var ran = false;

    await runOptionalStartupStep('quick', () async => ran = true);

    expect(ran, isTrue);
  });
}
