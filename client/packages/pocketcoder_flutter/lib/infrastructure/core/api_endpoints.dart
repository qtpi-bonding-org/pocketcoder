/// Canonical Flutter inventory for PocketCoder operations beyond the standard
/// PocketBase collection API.
///
/// Durable collection CRUD does not belong here. Dynamic path methods mirror
/// backend route templates while keeping raw `/api/pocketcoder/*` strings out
/// of feature repositories and transports.
abstract final class ApiEndpoints {
  static const String _root = '/api/pocketcoder';

  // Agent session operations and stream.
  static String agentPrompt(String chatId) =>
      '$_root/chats/$chatId/session/prompt';
  static String agentStream(String chatId) => '$_root/chats/$chatId/stream';
  static String agentCancel(String chatId) =>
      '$_root/chats/$chatId/session/cancel';
  static String agentSetMode(String chatId) =>
      '$_root/chats/$chatId/session/set_mode';
  static String agentSetConfigOption(String chatId) =>
      '$_root/chats/$chatId/session/set_config_option';
  static String agentPermission(String chatId, String requestId) =>
      '$_root/chats/$chatId/session/request_permission/$requestId';
  static String agentElicitation(String chatId, String elicitationId) =>
      '$_root/chats/$chatId/session/elicitation/$elicitationId';

  // Harness authentication lifecycle.
  static const String harnessAuthStatus = '$_root/harness_auth/status';
  static const String harnessAuthStart = '$_root/harness_auth/start';
  static const String harnessAuthPoll = '$_root/harness_auth/poll';
  static const String harnessAuthSubmit = '$_root/harness_auth/submit';
  static const String harnessAuthCancel = '$_root/harness_auth/cancel';
  static const String harnessAuthDisconnect = '$_root/harness_auth/disconnect';

  // The schedule record itself uses Collections.scheduleOwners.
  static const String schedulesRunNow = '$_root/schedules/run-now';

  // Workspace reads.
  static String files(String path) => '$_root/files/$path';
  static String filesList(String path) => '$_root/files-list/$path';

  // Private Ollama proxy.
  static const String ollamaModels = '$_root/ollama/models';
  static const String ollamaPull = '$_root/ollama/pull';

  // MCP operations.
  static const String mcpRequest = '$_root/mcp_request';
  static const String mcpOAuthStore = '$_root/mcp_oauth/store';

  // Release/update state, named after the release manifest JSON contract.
  static const String releaseCompatibility = '$_root/release/compatibility';
  static const String releaseStatus = '$_root/release/status';

  // Deployment diagnostics and dispatch.
  static String logs(String containerName) => '$_root/logs/$containerName';
  static const String observability = '$_root/proxy/observability/';
  static const String push = '$_root/push';

  /// Static routes, used by the backend/client parity check.
  static const List<String> staticRoutes = [
    harnessAuthStatus,
    harnessAuthStart,
    harnessAuthPoll,
    harnessAuthSubmit,
    harnessAuthCancel,
    harnessAuthDisconnect,
    schedulesRunNow,
    ollamaModels,
    ollamaPull,
    mcpRequest,
    mcpOAuthStore,
    releaseCompatibility,
    releaseStatus,
    push,
  ];

  /// Dynamic backend templates, used by the backend/client parity check.
  static const List<String> dynamicRoutes = [
    '$_root/chats/{chatId}/session/prompt',
    '$_root/chats/{chatId}/stream',
    '$_root/chats/{chatId}/session/cancel',
    '$_root/chats/{chatId}/session/set_mode',
    '$_root/chats/{chatId}/session/set_config_option',
    '$_root/chats/{chatId}/session/request_permission/{id}',
    '$_root/chats/{chatId}/session/elicitation/{id}',
    '$_root/files/{path...}',
    '$_root/files-list/{path...}',
    '$_root/logs/{containerName}',
    '$_root/proxy/observability/{path...}',
  ];

  static bool isCustomEndpoint(String path) => path.startsWith('$_root/');

  static bool isSafeFilePath(String path) {
    if (path.isEmpty || path.startsWith('/')) return false;
    if (path.contains('..') || path.contains('//')) return false;
    return true;
  }
}
