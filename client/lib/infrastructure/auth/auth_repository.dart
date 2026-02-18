import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:test_app/domain/auth/i_auth_repository.dart';
import '../core/collections.dart';
import '../core/auth_store.dart';
import '../../domain/exceptions.dart';
import '../../core/try_operation.dart';

@LazySingleton(as: IAuthRepository)
class AuthRepository implements IAuthRepository {
  final PocketBase _pocketBase;
  final AuthStoreConfig _authStoreConfig;

  AuthRepository(this._pocketBase, this._authStoreConfig);

  @override
  Stream<bool> get connectionStatus {
    if (_pocketBase is $PocketBase) {
      return (_pocketBase as $PocketBase).connectivity.statusStream;
    }
    return Stream.value(true);
  }

  @override
  Future<bool> login(String email, String password) async {
    return tryMethod(
      () async {
        await _pocketBase.collection(Collections.users).authWithPassword(email, password);
        return true;
      },
      AuthException.new,
      'login',
    );
  }

  @override
  Future<void> logout() async {
    _pocketBase.authStore.clear();
    await _authStoreConfig.clear();
  }

  @override
  Future<bool> refreshToken() async {
    return tryMethod(
      () async {
        await _pocketBase.collection(Collections.users).authRefresh();
        return true;
      },
      AuthException.new,
      'refreshToken',
    );
  }

  @override
  bool get isAuthenticated => _pocketBase.authStore.isValid;

  @override
  String? get currentUserId => _pocketBase.authStore.record?.id;

  @override
  String? get currentUserEmail => _pocketBase.authStore.record?.getStringValue('email');

  @override
  String? get currentUserRole => _pocketBase.authStore.record?.getStringValue('role');

  @override
  Future<bool> approvePermission(String permissionId) async {
    return tryMethod(
      () async {
        await _pocketBase.collection(Collections.permissions).update(permissionId, body: {
          'status': 'authorized',
        });
        return true;
      },
      AuthException.new,
      'approvePermission',
    );
  }

  @override
  Future<bool> healthCheck() async {
    return tryMethod(
      () async {
        final health = await _pocketBase.health.check();
        return health.code == 200;
      },
      AuthException.new,
      'healthCheck',
    );
  }

  @override
  void updateBaseUrl(String url) {
    _pocketBase.baseURL = url;
  }

  /// Get SSH keys for authorized_keys file
  Future<String> getSshKeysForAuthorizedKeys() async {
    return tryMethod(
      () async {
        final response = await _pocketBase.send('/api/pocketcoder/ssh_keys');
        return response.body as String;
      },
      AuthException.new,
      'getSshKeysForAuthorizedKeys',
    );
  }
}
