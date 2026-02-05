import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:test_app/domain/auth/i_auth_repository.dart';
import 'package:test_app/infrastructure/security/security_service.dart';

@LazySingleton(as: IAuthRepository)
class AuthRepository implements IAuthRepository {
  final PocketBase _pocketBase;
  final SecurityService _securityService;

  AuthRepository(this._pocketBase, this._securityService);

  @override
  Future<bool> registerDevice() async {
    try {
      final publicJwk = await _securityService.generateAndStoreKeyPair();

      final user = _pocketBase.authStore.record;
      if (user is RecordModel) {
        await _pocketBase.collection('users').update(user.id, body: {
          'publicKey': publicJwk,
        });
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> signChallenge(String challenge) async {
    try {
      if (!await _securityService.hasKey()) return null;
      return await _securityService.signChallenge(challenge);
    } catch (e) {
      return null;
    }
  }
}
