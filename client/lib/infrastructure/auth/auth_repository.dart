import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:test_app/domain/auth/i_auth_repository.dart';

@LazySingleton(as: IAuthRepository)
class AuthRepository implements IAuthRepository {
  final PocketBase _pocketBase;

  AuthRepository(this._pocketBase);

  @override
  Stream<bool> get connectionStatus {
    if (_pocketBase is $PocketBase) {
      return (_pocketBase as $PocketBase).connectivity.statusStream;
    }
    return Stream.value(true); // Fallback if not using drift wrapper
  }

  @override
  Future<bool> login(String email, String password) async {
    try {
      await _pocketBase.collection('users').authWithPassword(email, password);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> approvePermission(String permissionId) async {
    try {
      await _pocketBase.collection('permissions').update(permissionId, body: {
        'status': 'authorized',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final health = await _pocketBase.health.check();
      return health.code == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  void updateBaseUrl(String url) {
    _pocketBase.baseURL = url;
  }
}
