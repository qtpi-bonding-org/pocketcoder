import 'package:pocketcoder/domain/auth/auth_failure.dart';
import 'package:pocketbase/pocketbase.dart';

abstract class IAuthRepository {
  Future<AuthFailure?> signInWithEmailAndPassword(
      {required String email, required String password});

  Future<AuthFailure?> registerDevice();

  Future<void> signOut();

  Future<RecordModel?> getSignedInUser();

  /// Returns a record with either failure or signature
  Future<({AuthFailure? failure, String? signature})> signChallenge(
      String challenge);
}
