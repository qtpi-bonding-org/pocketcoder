import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import '../../domain/auth/i_auth_repository.dart';
import '../../domain/auth/user.dart';
import '../../domain/ssh/ssh_key.dart';
import '../core/collections.dart';
import '../core/auth_store.dart';
import '../../domain/exceptions.dart';
import '../../core/try_operation.dart';
import 'auth_daos.dart';

@LazySingleton(as: IAuthRepository)
class AuthRepository implements IAuthRepository {
  final PocketBase _pocketBase;
  final AuthStoreConfig _authStoreConfig;
  final UserDao _userDao;
  final SshKeyDao _sshKeyDao;

  AuthRepository(
    this._pocketBase,
    this._authStoreConfig,
    this._userDao,
    this._sshKeyDao,
  );

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
        await _pocketBase
            .collection(Collections.users)
            .authWithPassword(email, password);
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
  String? get currentUserEmail =>
      _pocketBase.authStore.record?.getStringValue('email');

  @override
  String? get currentUserRole =>
      _pocketBase.authStore.record?.getStringValue('role');

  @override
  void updateBaseUrl(String url) {
    _pocketBase.baseURL = url;
  }

  // --- Users ---

  @override
  Future<List<User>> getUsers() async {
    return _userDao.getFullList(sort: 'email');
  }

  // --- SSH Keys ---

  @override
  Future<List<SshKey>> getSshKeys() async {
    return _sshKeyDao.getFullList(sort: '-created');
  }

  @override
  Future<void> addSshKey(String title, String key) async {
    await _sshKeyDao.save(null, {
      'title': title,
      'key': key,
      'user': currentUserId,
    });
  }

  @override
  Future<void> deleteSshKey(String id) async {
    await _sshKeyDao.delete(id);
  }

  @override
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
