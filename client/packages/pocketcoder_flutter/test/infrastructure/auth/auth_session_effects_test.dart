import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/infrastructure/auth/auth_session_effects.dart';

class _MockAuthRepository extends Mock implements IAuthRepository {}

class _MockBillingService extends Mock implements BillingService {}

class _MockPushService extends Mock implements PushService {}

void main() {
  late _MockAuthRepository repository;
  late _MockBillingService billing;
  late _MockPushService push;
  late StreamController<void> changes;
  late AuthSessionCoordinator coordinator;
  String? userId;

  setUp(() {
    repository = _MockAuthRepository();
    billing = _MockBillingService();
    push = _MockPushService();
    changes = StreamController<void>.broadcast();
    userId = null;
    when(() => repository.authChanges).thenAnswer((_) => changes.stream);
    when(() => repository.isAuthenticated).thenAnswer((_) => userId != null);
    when(() => repository.currentUserId).thenAnswer((_) => userId);
    when(() => repository.currentBaseUrl).thenReturn('https://box');
    when(() => push.syncAuthenticatedDevice()).thenAnswer((_) async {});
    when(() => push.unregisterAuthenticatedDevice()).thenAnswer((_) async {});
    when(() => billing.reset()).thenAnswer((_) async {});
    coordinator = AuthSessionCoordinator(repository);
  });

  tearDown(() => changes.close());

  Future<void> signIn(String id) async {
    userId = id;
    changes.add(null);
    await pumpEventQueue();
  }

  Future<void> signOut() async {
    userId = null;
    changes.add(null);
    await pumpEventQueue();
  }

  test('a transient identify failure remains retryable', () async {
    var attempts = 0;
    when(() => billing.identify('user-1')).thenAnswer((_) {
      attempts += 1;
      if (attempts == 1) {
        throw Exception('network blip');
      }
      return Future<void>.value();
    });
    final effects = AuthSessionEffects(coordinator, billing, push);
    effects.start();

    await signIn('user-1');
    await signIn('user-1');

    verify(() => billing.identify('user-1')).called(2);
  });

  test('rapid sign-ins wait for the prior sign-in to finish', () async {
    final billingA = Completer<void>();
    final pushA = Completer<void>();
    final calls = <String>[];
    when(() => billing.identify('a')).thenAnswer((_) {
      calls.add('billing-a');
      return billingA.future;
    });
    when(() => billing.identify('b')).thenAnswer((_) async {
      calls.add('billing-b');
    });
    when(() => push.syncAuthenticatedDevice()).thenAnswer((_) {
      if (calls.contains('billing-b')) {
        calls.add('push-b');
        return Future<void>.value();
      }
      calls.add('push-a');
      return pushA.future;
    });
    final effects = AuthSessionEffects(coordinator, billing, push);
    effects.start();

    await signIn('a');
    await signIn('b');
    expect(calls, ['billing-a']);
    billingA.complete();
    await pumpEventQueue();
    expect(calls, ['billing-a', 'push-a']);
    pushA.complete();
    await pumpEventQueue();
    expect(calls, ['billing-a', 'push-a', 'billing-b', 'push-b']);
  });

  test('refresh snapshots do not repeat effects', () async {
    when(() => billing.identify('user-1')).thenAnswer((_) async {});
    final effects = AuthSessionEffects(coordinator, billing, push);
    effects.start();

    await signIn('user-1');
    await signIn('user-1');

    verify(() => billing.identify('user-1')).called(1);
    verify(() => push.syncAuthenticatedDevice()).called(1);
  });

  test('re-signing in to the same identity re-runs its effects', () async {
    when(() => billing.identify('user-1')).thenAnswer((_) async {});
    final effects = AuthSessionEffects(coordinator, billing, push);
    effects.start();

    await signIn('user-1');
    await signOut();
    await signIn('user-1');

    verify(() => billing.identify('user-1')).called(2);
    verify(() => push.syncAuthenticatedDevice()).called(2);
  });

  test('a later sign-out re-runs its effects', () async {
    when(() => billing.identify('user-1')).thenAnswer((_) async {});
    final effects = AuthSessionEffects(coordinator, billing, push);
    effects.start();

    // The replayed initial signed-out snapshot schedules the first sign-out.
    await pumpEventQueue();
    await signIn('user-1');
    await signOut();

    verify(() => push.unregisterAuthenticatedDevice()).called(2);
    verify(() => billing.reset()).called(2);
  });
}
