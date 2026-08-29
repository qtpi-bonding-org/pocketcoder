import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/exceptions/chat_list_exception.dart';

/// Maps PocketCoder's typed domain exceptions to short, stable codes for
/// the local error inbox. No string-matching on `error.toString()` — every
/// exception that reaches this point is already type-only by construction
/// (see `tryMethod`'s `SafeExceptionCause` wrapping), so message-content
/// heuristics would be dead code, not a safety net.
class PocketCoderErrorCodeMapper {
  PocketCoderErrorCodeMapper._();

  static final Map<Type, String> _codes = {
    AuthException: 'AUTH_001',
    ChatException: 'CHAT_001',
    ChatListException: 'CHATLIST_001',
    PermissionException: 'PERM_001',
    AiException: 'AI_001',
    ToolPermissionsException: 'TOOLPERM_001',
    RepositoryException: 'REPO_001',
    McpException: 'MCP_001',
    McpOAuthException: 'MCP_002',
    ObservabilityException: 'OBS_001',
    SkillsException: 'SKILLS_001',
    SchedulerException: 'SCHED_001',
    FilesException: 'FILES_001',
  };

  static String mapError(Object error) {
    return _codes[error.runtimeType] ?? 'ERR_${error.runtimeType}';
  }
}
