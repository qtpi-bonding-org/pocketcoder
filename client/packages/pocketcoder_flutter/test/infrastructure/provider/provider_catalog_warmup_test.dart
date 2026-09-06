import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_catalog_warmup.dart';

class _MockAuthRepository extends Mock implements IAuthRepository {}

class _MockProviderRepository extends Mock implements IProviderRepository {}

void main() {
  late _MockAuthRepository authRepository;
  late _MockProviderRepository providerRepository;
  late StreamController<void> changes;
  late AuthSessionCoordinator coordinator;
  String? userId;

  setUp(() {
    authRepository = _MockAuthRepository();
    providerRepository = _MockProviderRepository();
    changes = StreamController<void>.broadcast();
    userId = null;
    when(() => authRepository.authChanges).thenAnswer((_) => changes.stream);
    when(() => authRepository.isAuthenticated)
        .thenAnswer((_) => userId != null);
    when(() => authRepository.currentUserId).thenAnswer((_) => userId);
    when(() => authRepository.currentBaseUrl).thenReturn('https://box');
    when(() => providerRepository.fetchModels()).thenAnswer((_) async => []);
    when(() => providerRepository.fetchHarnessModels())
        .thenAnswer((_) async => []);
    coordinator = AuthSessionCoordinator(authRepository);
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

  test('signing in warms both catalog fetches', () async {
    final warmup = ProviderCatalogWarmup(coordinator, providerRepository);
    warmup.start();

    await signIn('user-1');

    verify(() => providerRepository.fetchModels()).called(1);
    verify(() => providerRepository.fetchHarnessModels()).called(1);
  });

  test('an already-signed-in session warms immediately on start()', () async {
    userId = 'user-1';
    coordinator = AuthSessionCoordinator(authRepository);

    final warmup = ProviderCatalogWarmup(coordinator, providerRepository);
    warmup.start();
    await pumpEventQueue();

    verify(() => providerRepository.fetchModels()).called(1);
    verify(() => providerRepository.fetchHarnessModels()).called(1);
  });

  test('a signed-out session does not warm anything', () async {
    final warmup = ProviderCatalogWarmup(coordinator, providerRepository);
    warmup.start();
    await pumpEventQueue();

    verifyNever(() => providerRepository.fetchModels());
    verifyNever(() => providerRepository.fetchHarnessModels());
  });

  test('a fetch failure does not crash and does not block the other fetch',
      () async {
    when(() => providerRepository.fetchModels())
        .thenThrow(Exception('network unreachable'));
    final warmup = ProviderCatalogWarmup(coordinator, providerRepository);
    warmup.start();

    await signIn('user-1');

    verify(() => providerRepository.fetchHarnessModels()).called(1);
  });
}
