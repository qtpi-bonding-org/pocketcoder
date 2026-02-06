abstract class IAuthRepository {
  /// Stream of online/offline status
  Stream<bool> get connectionStatus;

  /// Authenticates using email and password.
  Future<bool> login(String email, String password);

  /// Generates a key pair and registers it with the backend for the current user.
  Future<bool> registerDevice();

  /// Signs a challenge provided by the backend.
  /// Returns the signature or null if failed/cancelled.
  Future<String?> signChallenge(String challenge);
}
