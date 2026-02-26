/// Collection name constants for PocketBase to avoid typos and provide type safety.
///
/// Usage:
/// ```dart
/// _pb.collection(Collections.users).getList(...)
/// _pb.collection(Collections.chats).create(...)
/// ```
class Collections {
  // ===========================================================================
  // AUTH COLLECTIONS
  // ===========================================================================

  /// Users collection - contains user accounts with roles
  static const String users = 'users';

  // ===========================================================================
  // APP COLLECTIONS
  // ===========================================================================

  /// AI Models collection - available AI models
  static const String aiModels = 'ai_models';

  /// AI Prompts collection - system prompts for agents
  static const String aiPrompts = 'ai_prompts';

  /// AI Agents collection - agent configurations
  static const String aiAgents = 'ai_agents';

  /// Chats collection - chat sessions
  static const String chats = 'chats';

  /// Messages collection - chat messages with roles and parts
  static const String messages = 'messages';

  /// Permissions collection - permission requests and authorizations
  static const String permissions = 'permissions';

  /// SSH Keys collection - SSH public keys for user devices
  static const String sshKeys = 'ssh_keys';

  /// Whitelist Targets collection - glob patterns for whitelisting
  static const String whitelistTargets = 'whitelist_targets';

  /// Whitelist Actions collection - actions for whitelist patterns
  static const String whitelistActions = 'whitelist_actions';

  /// Proposals collection - feature proposals
  static const String proposals = 'proposals';

  /// SOPs collection - Standard Operating Procedures
  static const String sops = 'sops';

  /// Subagents collection - subagent configurations
  static const String subagents = 'subagents';

  /// Healthchecks collection - service health status
  static const String healthchecks = 'healthchecks';

  /// MCP Servers collection - capability registry
  static const String mcpServers = 'mcp_servers';

  /// Devices collection - for push notifications
  static const String devices = 'devices';

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  /// Returns all app collections (non-system, non-auth)
  static const List<String> appCollections = [
    aiModels,
    aiPrompts,
    aiAgents,
    chats,
    messages,
    permissions,
    sshKeys,
    whitelistTargets,
    whitelistActions,
    proposals,
    sops,
    subagents,
    healthchecks,
    mcpServers,
    devices,
  ];

  /// Returns all collections that exist in the current schema
  static const List<String> schemaCollections = [
    users,
    aiModels,
    aiPrompts,
    aiAgents,
    chats,
    messages,
    permissions,
    sshKeys,
    whitelistTargets,
    whitelistActions,
    proposals,
    sops,
    subagents,
    healthchecks,
    mcpServers,
    devices,
  ];

  /// Returns collections that are referenced in API docs but may not exist yet
  static const List<String> plannedCollections = [];

  /// Validates if a collection name exists in the current schema
  static bool existsInSchema(String collection) {
    return schemaCollections.contains(collection);
  }

  /// Checks if a collection is planned but not yet implemented
  static bool isPlanned(String collection) {
    return plannedCollections.contains(collection);
  }
}
