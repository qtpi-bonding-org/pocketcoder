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
  // APP COLLECTIONS (with pc_ prefix per backend spec)
  // ===========================================================================

  /// AI Models collection - available AI models
  static const String aiModels = 'pc_ai_models';

  /// AI Prompts collection - system prompts for agents
  static const String aiPrompts = 'pc_ai_prompts';

  /// AI Agents collection - agent configurations
  static const String aiAgents = 'pc_ai_agents';

  /// AI Permission Rules collection - permission rules for agents
  static const String aiPermissionRules = 'ai_permission_rules';

  /// Chats collection - chat sessions
  static const String chats = 'pc_chats';

  /// Messages collection - chat messages with roles and parts
  static const String messages = 'pc_messages';

  /// Permissions collection - permission requests and authorizations
  static const String permissions = 'pc_permissions';

  /// Usages collection - tracks AI model usage and costs
  static const String usages = 'pc_usages';

  /// SSH Keys collection - SSH public keys for user devices
  static const String sshKeys = 'pc_ssh_keys';

  /// Whitelist Targets collection - glob patterns for whitelisting
  static const String whitelistTargets = 'pc_whitelist_targets';

  /// Whitelist Actions collection - actions for whitelist patterns
  static const String whitelistActions = 'pc_whitelist_actions';

  /// Proposals collection - feature proposals
  static const String proposals = 'pc_proposals';

  /// SOPs collection - Standard Operating Procedures
  static const String sops = 'pc_sops';

  /// Subagents collection - subagent configurations
  static const String subagents = 'pc_subagents';

  /// Healthchecks collection - service health status
  static const String healthchecks = 'healthchecks';

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  /// Returns all app collections (non-system, non-auth)
  static const List<String> appCollections = [
    aiModels,
    aiPrompts,
    aiAgents,
    aiPermissionRules,
    chats,
    messages,
    permissions,
    usages,
    sshKeys,
    whitelistTargets,
    whitelistActions,
    proposals,
    sops,
    subagents,
    healthchecks,
  ];

  /// Returns all collections that exist in the current schema
  static const List<String> schemaCollections = [
    users,
    aiModels,
    aiPrompts,
    aiAgents,
    aiPermissionRules,
    chats,
    messages,
    permissions,
    usages,
    sshKeys,
    whitelistTargets,
    whitelistActions,
    proposals,
    sops,
    subagents,
    healthchecks,
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