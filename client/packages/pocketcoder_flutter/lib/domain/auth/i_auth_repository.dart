abstract class IAuthRepository {
  Stream<bool> get connectionStatus;

  Future<bool> login(String email, String password);
  Future<void> logout();
  Future<bool> refreshToken();

  /// Rejects a server whose public contract cannot be spoken by this app.
  /// This check is intentionally unauthenticated and runs before login.
  Future<void> verifyServerCompatibility();

  bool get isAuthenticated;
  String? get currentUserId;
  String? get currentUserEmail;
  String? get currentUserRole;

  Future<void> updateBaseUrl(String url);
  Future<String?> getSavedBaseUrl();

}
