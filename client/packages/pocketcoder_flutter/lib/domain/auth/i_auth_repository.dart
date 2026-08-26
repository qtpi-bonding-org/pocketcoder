abstract class IAuthRepository {
  Stream<bool> get connectionStatus;

  /// Notifications from the underlying auth store.
  Stream<void> get authChanges;

  Future<bool> login(String email, String password);
  Future<void> logout();
  Future<AuthRefreshResult> refreshToken();

  /// Rejects a server whose public contract cannot be spoken by this app.
  /// This check is intentionally unauthenticated and runs before login.
  Future<void> verifyServerCompatibility();

  bool get isAuthenticated;
  String? get currentUserId;
  String? get currentUserEmail;
  String? get currentUserRole;
  String? get currentBaseUrl;

  /// Sets the active base URL for subsequent calls (e.g.
  /// verifyServerCompatibility/login), in memory only -- not persisted.
  /// Callers must call [persistBaseUrl] once the URL is confirmed good.
  Future<void> updateBaseUrl(String url);

  /// Durably saves [url] as the server URL to restore on next launch.
  /// Only call this once [url] has actually been verified/used
  /// successfully -- persisting an unverified URL can strand the user
  /// with no path back to their real, working deployment.
  Future<void> persistBaseUrl(String url);

  Future<String?> getSavedBaseUrl();
}

/// Result of attempting to restore a persisted PocketBase session.
enum AuthRefreshResult {
  refreshed,
  temporarilyUnavailable,
  invalidSession,
}
