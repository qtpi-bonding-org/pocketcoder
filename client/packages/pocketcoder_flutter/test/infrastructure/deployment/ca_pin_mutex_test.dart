import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/ca_pin_mutex.dart';

void main() {
  test('serializes two concurrent synchronized() calls', () async {
    final mutex = CaPinMutex();
    final order = <String>[];
    final completerA = Completer<void>();

    final futureA = mutex.synchronized(() async {
      order.add('A start');
      await completerA.future;
      order.add('A end');
    });
    await Future<void>.delayed(Duration.zero);

    final futureB = mutex.synchronized(() async {
      order.add('B start');
    });

    await Future<void>.delayed(Duration.zero);
    expect(order, ['A start']);

    completerA.complete();
    await Future.wait([futureA, futureB]);
    expect(order, ['A start', 'A end', 'B start']);
  });

  test('releases even if the action throws', () async {
    final mutex = CaPinMutex();
    await expectLater(
      mutex.synchronized(() async => throw StateError('boom')),
      throwsA(isA<StateError>()),
    );
    final result =
        await mutex.synchronized(() async => 'ok').timeout(const Duration(seconds: 2));
    expect(result, 'ok');
  });
}
