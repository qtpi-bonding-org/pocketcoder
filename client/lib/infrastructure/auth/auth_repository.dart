import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder/domain/auth/auth_failure.dart';
import 'package:pocketcoder/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder/infrastructure/security/security_service.dart';

@LazySingleton(as: IAuthRepository)
class AuthRepository implements IAuthRepository {
  final PocketBase _pocketBase;
  final SecurityService _securityService;

  AuthRepository(this._pocketBase, this._securityService);

  @override
  Future<RecordModel?> getSignedInUser() async {
    final user = _pocketBase.authStore.model;
    if (user is RecordModel) {
      return user;
    }
    return null;
  }

  @override
  Future<AuthFailure?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _pocketBase.collection('users').authWithPassword(email, password);
      return null;
    } on ClientException catch (_) {
      return const AuthFailure.invalidEmailAndPasswordCombination();
    } catch (_) {
      return const AuthFailure.serverError();
    }
  }

  @override
  Future<void> signOut() async {
    _pocketBase.authStore.clear();
  }

  @override
  Future<AuthFailure?> registerDevice() async {
    try {
      // 1. Generate local key pair
      final publicJwk = await _securityService.generateAndStoreKeyPair();

      // 2. Send Public Key to Backend
      // We update the current user's record with the public key.
      // Assuming 'publicKey' field exists in 'users' collection (JSON type).
      final user = _pocketBase.authStore.model;
      if (user is RecordModel) {
        await _pocketBase.collection('users').update(user.id, body: {
          'publicKey': publicJwk,
        });
        return null;
      }
      return const AuthFailure.serverError();
    } catch (e) {
      return const AuthFailure.serverError();
    }
  }

  @override
  Future<({AuthFailure? failure, String? signature})> signChallenge(
      String challenge) async {
    try {
      if (!await _securityService.hasKey()) {
        return (failure: const AuthFailure.keyPairMissing(), signature: null);
      }
      final signature = await _securityService.signChallenge(challenge);
      return (failure: null, signature: signature);
    } catch (e) {
      return (
        failure: AuthFailure.biometricError(e.toString()),
        signature: null
      );
    }
  }
}
