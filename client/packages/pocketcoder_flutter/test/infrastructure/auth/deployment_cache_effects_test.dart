import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/auth/deployment_cache_effects.dart';

class _Repository implements IAuthRepository {
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool authenticated;
  String? baseUrl;
  AuthRefreshResult refreshResult = AuthRefreshResult.refreshed;

  _Repository({required this.authenticated, this.baseUrl});

  void publish() => _changes.add(null);

  @override
  Stream<bool> get connectionStatus => Stream.value(true);
  @override
  Stream<void> get authChanges => _changes.stream;
  @override
  bool get isAuthenticated => authenticated;
  @override
  String? get currentUserId => authenticated ? 'user-1' : null;
  @override
  String? get currentUserEmail => null;
  @override
  String? get currentUserRole => null;
  @override
  String? get currentBaseUrl => baseUrl;
  @override
  Future<bool> login(String email, String password) async => true;
  @override
  Future<void> logout() async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<AuthRefreshResult> refreshToken() async => refreshResult;
  @override
  Future<void> verifyServerCompatibility() async {}
  @override
  Future<void> updateBaseUrl(String url) async => baseUrl = url;
  @override
  Future<void> persistBaseUrl(String url) async => baseUrl = url;
  @override
  Future<String?> getSavedBaseUrl() async => baseUrl;

  Future<void> dispose() => _changes.close();
}

Future<$PocketBase> _client() async {
  final store = $AuthStore(save: (_) async {});
  return $PocketBase.database(
    'https://one.example',
    inMemory: true,
    authStore: store,
    requestPolicy: RequestPolicy.cacheOnly,
  );
}

Future<void> _seed($PocketBase client) => client.db.setLocal('healthchecks', [
      {
        'id': 'old-row',
        'name': 'old deployment row',
        'status': 'ready',
      },
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late $PocketBase client;
  late _Repository repository;
  late AuthSessionCoordinator coordinator;
  late DeploymentCacheEffects effects;
  Future<void> Function()? clearOverride;

  setUp(() async {
    client = await _client();
    repository =
        _Repository(authenticated: true, baseUrl: 'https://one.example');
    coordinator = AuthSessionCoordinator(repository, refreshRetryDelay: (_) async {});
    effects = DeploymentCacheEffects(
      coordinator,
      client,
      clearCache: () async {
        final override = clearOverride;
        if (override != null) {
          await override();
        } else {
          await client.db.clearAllData();
        }
      },
    );
    effects.start();
    await pumpEventQueue();
  });

  tearDown(() async {
    await repository.dispose();
    client.close();
  });

  test('first non-null snapshot does not clear the cache', () async {
    await _seed(client);
    expect((await client.db.$query('healthchecks').get()).length, 1);
  });

  test('different non-null base URL clears the local cache', () async {
    await _seed(client);
    repository.baseUrl = 'https://two.example';
    repository.publish();
    await pumpEventQueue();
    expect(await client.db.$query('healthchecks').get(), isEmpty);
  });

  test('same base URL does not clear, including redundant reconnect', () async {
    await _seed(client);
    repository.baseUrl = 'https://one.example';
    repository.publish();
    await pumpEventQueue();
    expect((await client.db.$query('healthchecks').get()).length, 1);
  });

  test('null base URL does not clear or corrupt the previous deployment URL',
      () async {
    await _seed(client);
    repository.baseUrl = null;
    repository.authenticated = false;
    repository.publish();
    await pumpEventQueue();
    expect((await client.db.$query('healthchecks').get()).length, 1);

    repository.baseUrl = 'https://two.example';
    repository.authenticated = true;
    repository.publish();
    await pumpEventQueue();
    expect((await client.db.$query('healthchecks').get()).length, 1);
  });

  test('temporarily unavailable restore does not clear cache', () async {
    await _seed(client);
    repository.refreshResult = AuthRefreshResult.temporarilyUnavailable;
    await coordinator.restore();
    await pumpEventQueue();
    expect((await client.db.$query('healthchecks').get()).length, 1);
  });

  test('serializes and de-duplicates a clear while it is in flight', () async {
    final clearStarted = Completer<void>();
    final allowClear = Completer<void>();
    var clearCalls = 0;
    clearOverride = () async {
      clearCalls++;
      clearStarted.complete();
      await allowClear.future;
    };

    repository.baseUrl = 'https://two.example';
    repository.publish();
    await clearStarted.future;

    // The first clear has not completed, so this must not schedule another
    // clear for the same target deployment.
    repository.publish();
    await pumpEventQueue();
    expect(clearCalls, 1);

    allowClear.complete();
    await pumpEventQueue();
    expect(clearCalls, 1);
  });

  test('retries a failed clear on a later snapshot', () async {
    var clearCalls = 0;
    clearOverride = () async {
      clearCalls++;
      if (clearCalls == 1) {
        throw StateError('temporary clear failure');
      }
    };

    repository.baseUrl = 'https://two.example';
    repository.publish();
    await pumpEventQueue();
    expect(clearCalls, 1);

    // The failed attempt did not advance the previous URL, so the same
    // transition remains eligible for retry.
    repository.publish();
    await pumpEventQueue();
    expect(clearCalls, 2);
  });
}
