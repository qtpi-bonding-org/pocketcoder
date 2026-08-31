import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';

class _MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late StreamController<void> authChanges;

  setUp(() {
    repository = _MockAuthRepository();
    authChanges = StreamController<void>.broadcast();
    when(() => repository.isAuthenticated).thenReturn(false);
    when(() => repository.authChanges).thenAnswer((_) => authChanges.stream);
    when(() => repository.currentBaseUrl).thenReturn(null);
    when(() => repository.currentUserId).thenReturn(null);
  });

  tearDown(() => authChanges.close());

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

  test('a session change that happens before the first listener attaches is not lost',
      () async {
    var authenticated = false;
    when(() => repository.isAuthenticated).thenAnswer((_) => authenticated);
    when(() => repository.currentUserId).thenAnswer(
      (_) => authenticated ? 'user-a' : null,
    );
    final coordinator = AuthSessionCoordinator(repository);

    authenticated = true;
    authChanges.add(null);
    final snapshot = await coordinator.sessionChanges.first;

    expect(snapshot.state, AuthSessionState.signedIn);
    expect(snapshot.userId, isNotNull);
  });

  test('subscribing then immediately logging in never yields only the pre-login snapshot',
      () async {
    var authenticated = false;
    when(() => repository.isAuthenticated).thenAnswer((_) => authenticated);
    when(() => repository.currentUserId).thenAnswer(
      (_) => authenticated ? 'user-a' : null,
    );
    when(() => repository.login(any(), any())).thenAnswer((_) async {
      authenticated = true;
      authChanges.add(null);
      return true;
    });
    final coordinator = AuthSessionCoordinator(repository);
    final states = <AuthSessionState>[];
    final sub = coordinator.sessionChanges.listen((s) => states.add(s.state));
    await repository.login('a@example.com', 'password');
    await pumpEventQueue();

    expect(states, contains(AuthSessionState.signedIn));
    await sub.cancel();
  });

  test('a user-A to user-B transition (no intervening signedOut) is visible',
      () async {
    String? userId;
    when(() => repository.isAuthenticated).thenReturn(true);
    when(() => repository.currentUserId).thenAnswer((_) => userId);
    final coordinator = AuthSessionCoordinator(repository);

    userId = 'user-a';
    authChanges.add(null);
    final firstUserId = (await coordinator.sessionChanges.first).userId;
    userId = 'user-b';
    authChanges.add(null);
    final snapshot = await coordinator.sessionChanges.first;

    expect(snapshot.userId, isNot(firstUserId));
  });

  test('baseUrl reflects the deployment the current session actually belongs to',
      () async {
    var baseUrl = 'https://box-a';
    when(() => repository.isAuthenticated).thenReturn(true);
    when(() => repository.currentUserId).thenReturn('user-a');
    when(() => repository.currentBaseUrl).thenAnswer((_) => baseUrl);
    final coordinator = AuthSessionCoordinator(repository);
    authChanges.add(null);

    expect((await coordinator.sessionChanges.first).baseUrl, 'https://box-a');
  });
}
