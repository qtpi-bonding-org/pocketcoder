import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';

void main() {
  test('maps an unmapped exception to safe generic text', () {
    final message = safeErrorMessage(StateError('private transport details'));

    expect(message, isNot(contains('Instance of')));
    expect(message, isNot(contains('StateError')));
    expect(message, isNot(contains('private transport details')));
  });
}
