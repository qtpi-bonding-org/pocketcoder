/// Custom API endpoint constants for PocketCoder backend.
///
/// These are the custom endpoints beyond standard PocketBase collection operations.
/// Usage:
/// ```dart
/// _pb.send(ApiEndpoints.permission, body: {...})
/// _pb.send(ApiEndpoints.sshKeys)
/// ```
class ApiEndpoints {
  // ===========================================================================
  // PERMISSION ENDPOINTS
  // ===========================================================================

  /// POST /api/pocketcoder/permission
  /// Evaluates if a permission request should be granted.
  /// Creates an audit record and returns authorization decision.
  static const String permission = '/api/pocketcoder/permission';

  // ===========================================================================
  // SSH KEY ENDPOINTS
  // ===========================================================================

  /// GET /api/pocketcoder/ssh_keys
  /// Returns all active SSH public keys as newline-separated list
  /// for authorized_keys file population.
  static const String sshKeys = '/api/pocketcoder/ssh_keys';

  // ===========================================================================
  // SESSION ENDPOINTS
  // ===========================================================================

  /// GET /api/pocketcoder/resolve_session/{session_id}
  /// Maps session IDs to tmux routing info for the proxy's smart router.
  /// Returns chat_id, window_id, and agent/subagent info.
  static String resolveSession(String sessionId) =>
      '/api/pocketcoder/resolve_session/$sessionId';

  // ===========================================================================
  // ARTIFACT/FILE ENDPOINTS
  // ===========================================================================

  /// GET /api/pocketcoder/artifact/{path}
  /// Secure read-only access to workspace files.
  /// Prevents path traversal and unauthorized access.
  static String artifact(String path) => '/api/pocketcoder/artifact/$path';

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  /// All custom endpoints (excluding dynamic ones)
  static const List<String> all = [
    permission,
    sshKeys,
  ];

  /// Dynamic endpoints that require parameters
  static const List<String> dynamicEndpoints = [
    '/api/pocketcoder/resolve_session/{session_id}',
    '/api/pocketcoder/artifact/{path}',
  ];

  /// Checks if an endpoint is a custom PocketCoder endpoint
  static bool isCustomEndpoint(String path) {
    return path.startsWith('/api/pocketcoder/');
  }

  /// Validates if a session ID looks valid (basic check)
  static bool isValidSessionId(String sessionId) {
    return sessionId.isNotEmpty && sessionId.length >= 8;
  }

  /// Validates if a path is safe for artifact access
  /// (prevents path traversal attacks)
  static bool isSafeArtifactPath(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('/')) return false; // Absolute paths not allowed
    if (path.contains('..')) return false; // Path traversal
    if (path.contains('//')) return false; // Double slashes
    return true;
  }
}