abstract class IAuthRepository {
  /// Generates a key pair and registers it with the backend for the current user.
  Future<bool> registerDevice();

  /// Signs a challenge provided by the backend.
  /// Returns the signature or null if failed/cancelled.
  Future<String?> signChallenge(String challenge);
}
