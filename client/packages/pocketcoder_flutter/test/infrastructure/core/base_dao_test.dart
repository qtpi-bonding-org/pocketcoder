import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/healthcheck.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/system/health_daos.dart';

String _token({required int expiry}) {
  String part(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none', 'typ': 'JWT'})}.${part({'exp': expiry, 'id': 'u1'})}.x';
}

Future<$PocketBase> _client(String token) async {
  final store = $AuthStore(save: (_) async {});
  store.save(token, null);
  return $PocketBase.database(
    'http://unused.local',
    inMemory: true,
    authStore: store,
    requestPolicy: RequestPolicy.cacheFirst,
  );
}

Future<void> _seed($PocketBase client) => client.db.setLocal('healthchecks', [
      {
        'id': 'h1',
        'name': 'api',
        'status': 'ready',
        'created': '2024-01-01 00:00:00.000Z',
        'updated': '2024-01-01 00:00:00.000Z',
      },
    ]);

class _AuthRepository implements IAuthRepository {
  final changes = StreamController<void>.broadcast();
  bool authenticated;
  String? baseUrl;
  AuthRefreshResult refreshResult = AuthRefreshResult.refreshed;

  _AuthRepository({required this.authenticated, this.baseUrl});

  void publish() => changes.add(null);

  @override
  Stream<bool> get connectionStatus => Stream.value(true);
  @override
  Stream<void> get authChanges => changes.stream;
  @override
  bool get isAuthenticated => authenticated;
  @override
  String? get currentUserId => authenticated ? 'u1' : null;
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
  Future<AuthRefreshResult> refreshToken() async => refreshResult;
  @override
  Future<void> verifyServerCompatibility() async {}
  @override
  Future<void> updateBaseUrl(String url) async => baseUrl = url;
  @override
  Future<void> persistBaseUrl(String url) async => baseUrl = url;
  @override
  Future<String?> getSavedBaseUrl() async => baseUrl;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late $PocketBase client;
  late HealthcheckDao dao;

  setUp(() async {
    BaseDao.clearSessionCoordinator();
    client = await _client('');
    dao = HealthcheckDao(client);
  });

  tearDown(() async {
    BaseDao.clearSessionCoordinator();
    client.close();
  });

  test('never-authenticated watch emits notAuthenticated', () async {
    await expectLater(dao.watch(), emitsError(isA<AuthException>()));
  });

  test('never-authenticated getFullList and getOne throw', () async {
    await expectLater(dao.getFullList(), throwsA(isA<AuthException>()));
    await expectLater(dao.getOne('h1'), throwsA(isA<AuthException>()));
  });

  test('no coordinator configured preserves the legacy cached-read path', () async {
    client = await _client(_token(expiry: 4102444800));
    dao = HealthcheckDao(client);
    await _seed(client);
    expect((await dao.watch().first).single.id, 'h1');
  });

  test('authenticated offline cache-first watch yields cached rows', () async {
    client = await _client(_token(expiry: 4102444800));
    dao = HealthcheckDao(client);
    await _seed(client);
    expect((await dao.watch().first).single.id, 'h1');
  });

  test('expired non-empty token still yields cache-first rows', () async {
    client = await _client(_token(expiry: 1));
    dao = HealthcheckDao(client);
    await _seed(client);
    expect(client.authStore.token, isNotEmpty);
    expect(client.authStore.isValid, isFalse);
    expect((await dao.watch().first).single.name, 'api');
  });

  test('expired network watch emits cached row then keeps later cache updates', () async {
    client = await _client(_token(expiry: 1));
    dao = HealthcheckDao(client);
    await _seed(client);
    final values = <List<Healthcheck>>[];
    final errors = <Object>[];
    dao.watch(requestPolicy: RequestPolicy.networkOnly).listen(
      values.add,
      onError: errors.add,
    );
    await pumpEventQueue();
    expect(values, hasLength(1));
    expect(values.single.single.id, 'h1');
    expect(errors, hasLength(1));
    expect(errors.single, isA<AuthException>());
    await client.db.setLocal('healthchecks', [
      {
        'id': 'h2',
        'name': 'worker',
        'status': 'ready',
        'created': '2024-01-01 00:00:00.000Z',
        'updated': '2024-01-01 00:00:00.000Z',
      },
    ], removeAll: false);
    await pumpEventQueue();
    expect(values.length, greaterThanOrEqualTo(2));
    expect(values.last.map((row) => row.id), contains('h2'));
  });

  test('session sign-out injects an error, while temporary unavailability does not', () async {
    client = await _client(_token(expiry: 4102444800));
    dao = HealthcheckDao(client);
    await _seed(client);
    final repository = _AuthRepository(authenticated: true, baseUrl: 'https://one');
    final coordinator = AuthSessionCoordinator(repository);
    BaseDao.configureSessionCoordinator(coordinator);
    final errors = <Object>[];
    final values = <List<Healthcheck>>[];
    final subscription = dao.watch(requestPolicy: RequestPolicy.cacheOnly).listen(
      values.add,
      onError: errors.add,
    );
    await Future<void>.delayed(Duration.zero);
    repository.refreshResult = AuthRefreshResult.temporarilyUnavailable;
    await coordinator.restore();
    await Future<void>.delayed(Duration.zero);
    expect(errors, isEmpty);
    repository.authenticated = false;
    repository.publish();
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    expect(errors.single, isA<AuthException>());
    repository.authenticated = true;
    repository.publish();
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    await subscription.cancel();
    await repository.changes.close();
  });
}
