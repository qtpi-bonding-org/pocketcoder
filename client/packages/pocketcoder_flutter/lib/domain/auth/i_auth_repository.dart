abstract class IAuthRepository {
  Stream<bool> get connectionStatus;

  Future<bool> login(String email, String password);
  Future<void> logout();
  Future<bool> refreshToken();

  bool get isAuthenticated;
  String? get currentUserId;
  String? get currentUserEmail;
  String? get currentUserRole;

  Future<void> updateBaseUrl(String url);
  Future<String?> getSavedBaseUrl();

  Future<String> getSshKeysForAuthorizedKeys();
}
