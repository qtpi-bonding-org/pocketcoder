import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';

class _MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late _MockAuthRepository repository;

  setUp(() {
    repository = _MockAuthRepository();
  });

  test('restores a valid persisted session silently', () async {
    when(() => repository.isAuthenticated).thenReturn(true);
    when(() => repository.refreshToken())
        .thenAnswer((_) async => AuthRefreshResult.refreshed);

    final state = await AuthSessionCoordinator(repository).restore();

    expect(state, AuthSessionState.signedIn);
  });

  test('preserves a session when the deployment is temporarily unavailable',
      () async {
    when(() => repository.isAuthenticated).thenReturn(true);
    when(() => repository.refreshToken()).thenAnswer(
      (_) async => AuthRefreshResult.temporarilyUnavailable,
    );

    final state = await AuthSessionCoordinator(repository).restore();

    expect(state, AuthSessionState.temporarilyUnavailable);
  });

  test('requires login only when the session is definitively invalid',
      () async {
    when(() => repository.isAuthenticated).thenReturn(true);
    when(() => repository.refreshToken())
        .thenAnswer((_) async => AuthRefreshResult.invalidSession);

    final state = await AuthSessionCoordinator(repository).restore();

    expect(state, AuthSessionState.signedOut);
  });

  test('does not contact the server without a persisted session', () async {
    when(() => repository.isAuthenticated).thenReturn(false);

    final state = await AuthSessionCoordinator(repository).restore();

    expect(state, AuthSessionState.signedOut);
    verifyNever(() => repository.refreshToken());
  });

  test('shares one refresh across concurrent callers', () async {
    final completer = Completer<AuthRefreshResult>();
    when(() => repository.refreshToken()).thenAnswer((_) => completer.future);
    final coordinator = AuthSessionCoordinator(repository);

    final first = coordinator.refresh();
    final second = coordinator.refresh();
    expect(identical(first, second), isTrue);

    completer.complete(AuthRefreshResult.refreshed);
    await Future.wait([first, second]);
    verify(() => repository.refreshToken()).called(1);
  });
}
