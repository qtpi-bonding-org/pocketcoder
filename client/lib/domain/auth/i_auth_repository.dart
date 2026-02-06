abstract class IAuthRepository {
  /// Stream of online/offline status
  Stream<bool> get connectionStatus;

  /// Authenticates using email and password.
  Future<bool> login(String email, String password);

  /// Approves a permission request by setting its status to authorized.
  Future<bool> approvePermission(String permissionId);
}
