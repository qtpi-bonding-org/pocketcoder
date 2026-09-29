import 'dart:async';

import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';

Future<void> runOptionalStartupStep(
  String name,
  Future<void> Function() step, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    await step().timeout(timeout);
  } on TimeoutException {
    AppLogger.warning('Optional startup step timed out -- skipping', {
      'step': name,
      'timeout': timeout.toString(),
    });
  } catch (error, stackTrace) {
    AppLogger.error(
        'Optional startup step failed -- skipping ($name)', error, stackTrace);
  }
}
