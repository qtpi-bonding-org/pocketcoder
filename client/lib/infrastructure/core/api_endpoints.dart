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
  // ARTIFACT/FILE ENDPOINTS
  // ===========================================================================

  /// GET /api/pocketcoder/artifact/{path}
  /// Secure read-only access to workspace files.
  /// Prevents path traversal and unauthorized access.
  static String artifact(String path) => '/api/pocketcoder/artifact/$path';

  // ===========================================================================
  // INFRASTRUCTURE ENDPOINTS
  // ===========================================================================

  /// GET /api/pocketcoder/health
  /// Returns system health status.
  static const String health = '/api/pocketcoder/health';

  // ===========================================================================
  // SUBAGENT ENDPOINTS
  // ===========================================================================

  /// POST /api/pocketcoder/subagent
  /// Orchestrates subagent creation and task delegation.
  static const String subagent = '/api/pocketcoder/subagent';

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  /// All custom endpoints (excluding dynamic ones)
  static const List<String> all = [
    permission,
    sshKeys,
    health,
    subagent,
  ];

  /// Dynamic endpoints that require parameters
  static const List<String> dynamicEndpoints = [
    '/api/pocketcoder/artifact/{path}',
  ];

  /// Checks if an endpoint is a custom PocketCoder endpoint
  static bool isCustomEndpoint(String path) {
    return path.startsWith('/api/pocketcoder/');
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
