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
  // FILE ENDPOINTS
  // ===========================================================================

  /// GET /api/pocketcoder/files/{path}
  /// Secure read-only access to workspace files.
  /// Prevents path traversal and unauthorized access.
  static String files(String path) => '/api/pocketcoder/files/$path';

  /// GET /api/pocketcoder/files-list/{path}
  /// Lists the immediate children of a workspace directory.
  static String filesList(String path) => '/api/pocketcoder/files-list/$path';

  // ===========================================================================
  // INFRASTRUCTURE ENDPOINTS
  // ===========================================================================

  /// GET /api/pocketcoder/health
  /// Returns system health status.
  static const String health = '/api/pocketcoder/health';

  /// GET /api/pocketcoder/compatibility
  /// Returns only public protocol versions; no release identity or host data.
  static const String compatibility = '/api/pocketcoder/compatibility';

  /// GET /api/pocketcoder/capabilities
  /// Returns authenticated release identity and cached update status.
  static const String capabilities = '/api/pocketcoder/capabilities';

  // ===========================================================================
  // OBSERVABILITY ENDPOINTS
  // ===========================================================================

  /// GET /api/pocketcoder/logs/{containerName}
  /// SSE stream of Docker container logs.
  static String logs(String containerName) =>
      '/api/pocketcoder/logs/$containerName';

  /// GET /api/pocketcoder/proxy/observability/*
  /// Proxy to SQLPage dashboard.
  static const String observability = '/api/pocketcoder/proxy/observability/';

  // ===========================================================================
  // SKILLS ENDPOINTS
  // ===========================================================================

  /// POST /api/pocketcoder/skills/list
  /// Lists all skills (global + every known poco_config's project scope).
  static const String skillsList = '/api/pocketcoder/skills/list';

  /// POST /api/pocketcoder/skills/create
  /// Creates a skill under global or project scope.
  static const String skillsCreate = '/api/pocketcoder/skills/create';

  /// POST /api/pocketcoder/skills/update
  /// Updates a skill's name/description/content by its stable path.
  static const String skillsUpdate = '/api/pocketcoder/skills/update';

  /// POST /api/pocketcoder/skills/delete
  /// Deletes a skill by its stable path.
  static const String skillsDelete = '/api/pocketcoder/skills/delete';

  // ===========================================================================
  // SCHEDULER ENDPOINTS
  // ===========================================================================

  /// POST /api/pocketcoder/schedules/list
  /// Lists the caller's own scheduled recipe runs.
  static const String schedulesList = '/api/pocketcoder/schedules/list';

  /// POST /api/pocketcoder/schedules/create
  /// Creates a new scheduled recipe run.
  static const String schedulesCreate = '/api/pocketcoder/schedules/create';

  /// POST /api/pocketcoder/schedules/rename
  /// Renames a schedule (PocketBase-side display name only).
  static const String schedulesRename = '/api/pocketcoder/schedules/rename';

  /// POST /api/pocketcoder/schedules/update-cron
  /// Updates a schedule's cron expression.
  static const String schedulesUpdateCron =
      '/api/pocketcoder/schedules/update-cron';

  /// POST /api/pocketcoder/schedules/pause
  static const String schedulesPause = '/api/pocketcoder/schedules/pause';

  /// POST /api/pocketcoder/schedules/unpause
  static const String schedulesUnpause = '/api/pocketcoder/schedules/unpause';

  /// POST /api/pocketcoder/schedules/delete
  static const String schedulesDelete = '/api/pocketcoder/schedules/delete';

  /// POST /api/pocketcoder/schedules/run-now
  /// Fires a schedule immediately (async — the resulting session is
  /// imported into the chat feed once it finishes, not returned here).
  static const String schedulesRunNow = '/api/pocketcoder/schedules/run-now';

  // ===========================================================================
  // MCP OAUTH ENDPOINTS
  // ===========================================================================

  /// POST /api/pocketcoder/mcp_oauth/store
  /// Merges an OAuth {access_token, refresh_token} pair into the target
  /// mcp_servers row's config, which hooks/mcp.go renders into mcp.env.
  static const String mcpOAuthStore = '/api/pocketcoder/mcp_oauth/store';

  // ===========================================================================
  // HARNESS AUTH ENDPOINTS
  // ===========================================================================

  /// POST /api/pocketcoder/harness_auth/status
  /// Returns current harness auth binding state and active attempt/challenge.
  static const String harnessAuthStatus =
      '/api/pocketcoder/harness_auth/status';

  /// POST /api/pocketcoder/harness_auth/start
  /// Starts a harness auth flow for a specific credential mode.
  static const String harnessAuthStart = '/api/pocketcoder/harness_auth/start';

  /// POST /api/pocketcoder/harness_auth/poll
  /// Polls the active auth attempt for the binding and returns latest status.
  static const String harnessAuthPoll = '/api/pocketcoder/harness_auth/poll';

  /// POST /api/pocketcoder/harness_auth/submit
  /// Submits a device/browser code for the active attempt.
  static const String harnessAuthSubmit =
      '/api/pocketcoder/harness_auth/submit';

  /// POST /api/pocketcoder/harness_auth/cancel
  /// Cancels the active auth attempt container.
  static const String harnessAuthCancel =
      '/api/pocketcoder/harness_auth/cancel';

  /// POST /api/pocketcoder/harness_auth/disconnect
  /// Clears the active auth binding and stops any auth helper state.
  static const String harnessAuthDisconnect =
      '/api/pocketcoder/harness_auth/disconnect';

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  /// All custom endpoints (excluding dynamic ones)
  static const List<String> all = [
    permission,
    sshKeys,
    health,
    compatibility,
    capabilities,
    observability,
    skillsList,
    skillsCreate,
    skillsUpdate,
    skillsDelete,
    schedulesList,
    schedulesCreate,
    schedulesRename,
    schedulesUpdateCron,
    schedulesPause,
    schedulesUnpause,
    schedulesDelete,
    schedulesRunNow,
    mcpOAuthStore,
    harnessAuthStatus,
    harnessAuthStart,
    harnessAuthPoll,
    harnessAuthSubmit,
    harnessAuthCancel,
    harnessAuthDisconnect,
  ];

  /// Dynamic endpoints that require parameters
  static const List<String> dynamicEndpoints = [
    '/api/pocketcoder/files/{path}',
    '/api/pocketcoder/files-list/{path}',
    '/api/pocketcoder/logs/{containerName}',
  ];

  /// Checks if an endpoint is a custom PocketCoder endpoint
  static bool isCustomEndpoint(String path) {
    return path.startsWith('/api/pocketcoder/');
  }

  /// Validates if a path is safe for file access
  /// (prevents path traversal attacks)
  static bool isSafeFilePath(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('/')) return false; // Absolute paths not allowed
    if (path.contains('..')) return false; // Path traversal
    if (path.contains('//')) return false; // Double slashes
    return true;
  }
}
