import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/exceptions/agent_config_exception.dart';
import 'package:pocketcoder_flutter/domain/exceptions/file_exception.dart';
import 'package:pocketcoder_flutter/domain/exceptions/model_search_exception.dart';
import 'package:pocketcoder_flutter/domain/exceptions/permission_exception.dart'
    as legacy;
import 'package:pocketcoder_flutter/domain/exceptions/proposal_exception.dart';
import 'package:pocketcoder_flutter/domain/exceptions/provider_exception.dart';
import 'package:pocketcoder_flutter/domain/exceptions/sandbox_agent_exception.dart';
import 'package:pocketcoder_flutter/domain/exceptions/session_exception.dart';
import 'package:pocketcoder_flutter/domain/exceptions/ssh_key_exception.dart';
import 'package:pocketcoder_flutter/domain/exceptions/user_exception.dart';

/// Maps PocketCoder's typed domain exceptions to short, stable codes for
/// the local error inbox. No string-matching on `error.toString()` — every
/// exception that reaches this point is already type-only by construction
/// (see `tryMethod`'s `SafeExceptionCause` wrapping), so message-content
/// heuristics would be dead code, not a safety net.
///
/// A code reads `BASE[.STEP][.CAUSE]`, e.g. `AUTH_001.LOGIN.DNS`. The inbox
/// groups entries by type, code and source, so each distinct step and cause
/// becomes its own row, and the code in a copied report says what failed.
/// The step comes from a fixed keyword list matched against the message
/// (a developer-chosen method label), never copied from it; the cause comes
/// from the exception types in the cause chain.
class PocketCoderErrorCodeMapper {
  PocketCoderErrorCodeMapper._();

  // Keyed by type name so two classes that share a name (the legacy
  // PermissionException) and types we cannot import both resolve.
  static const Map<String, String> _codes = {
    'AuthException': 'AUTH_001',
    'ChatException': 'CHAT_001',
    'ChatListException': 'CHATLIST_001',
    'PermissionException': 'PERM_001',
    'AiException': 'AI_001',
    'ToolPermissionsException': 'TOOLPERM_001',
    'RepositoryException': 'REPO_001',
    'McpException': 'MCP_001',
    'McpOAuthException': 'MCP_002',
    'ObservabilityException': 'OBS_001',
    'SkillsException': 'SKILLS_001',
    'SchedulerException': 'SCHED_001',
    'FilesException': 'FILES_001',
    'GitSshException': 'GITSSH_001',
    'BillingException': 'BILLING_001',
    'UserManagementException': 'USERMGMT_001',
    'LiveActivityException': 'LIVEACT_001',
    'AgentConfigException': 'AGENTCFG_001',
    'FileException': 'FILE_001',
    'ModelSearchException': 'MODELSEARCH_001',
    'ProposalException': 'PROPOSAL_001',
    'ProviderException': 'PROVIDER_001',
    'SandboxAgentException': 'SANDBOX_001',
    'SessionException': 'SESSION_001',
    'SSHKeyException': 'SSHKEY_001',
    'UserException': 'USER_001',
  };

  // First match wins; every entry is a fixed token, so nothing from the
  // message itself reaches the code.
  static const List<(String, String)> _steps = [
    ('compatib', 'COMPAT'),
    ('not authenticated', 'NOT_AUTHENTICATED'),
    ('login', 'LOGIN'),
    ('token', 'TOKEN'),
    ('fetch', 'FETCH'),
    ('send', 'SEND'),
    ('update', 'UPDATE'),
    ('save', 'SAVE'),
    ('restore', 'RESTORE'),
    ('purchase', 'PURCHASE'),
  ];

  static const int _maxCauseDepth = 6;

  static String mapError(Object error) {
    final type = error.runtimeType.toString();
    final step = _step(error);
    final cause = _cause(error, 0);
    return [
      _codes[type] ?? 'ERR_$type',
      if (step != null) step,
      if (cause != null) cause,
    ].join('.');
  }

  static String? _step(Object error) {
    final message = _messageOf(error)?.toLowerCase();
    if (message == null) return null;
    for (final (keyword, token) in _steps) {
      if (message.contains(keyword)) return token;
    }
    return null;
  }

  static String? _messageOf(Object error) => switch (error) {
        DomainException(:final message) ||
        legacy.PermissionException(:final message) ||
        AgentConfigException(:final message) ||
        FileException(:final message) ||
        ModelSearchException(:final message) ||
        ProposalException(:final message) ||
        ProviderException(:final message) ||
        SandboxAgentException(:final message) ||
        SessionException(:final message) ||
        SSHKeyException(:final message) ||
        UserException(:final message) =>
          message,
        _ => null,
      };

  /// The exception wrapped by [error], or null when [error] wraps nothing.
  /// The record's first field says whether [error] is a wrapper at all.
  static (bool, Object?) _unwrap(Object error) => switch (error) {
        DomainException(:final cause) => (true, cause),
        legacy.PermissionException(:final cause) ||
        AgentConfigException(:final cause) ||
        FileException(:final cause) ||
        ModelSearchException(:final cause) ||
        ProposalException(:final cause) ||
        ProviderException(:final cause) ||
        SandboxAgentException(:final cause) ||
        SessionException(:final cause) ||
        SSHKeyException(:final cause) ||
        UserException(:final cause) =>
          (true, cause),
        SafeExceptionCause(:final originalException) =>
          (true, originalException),
        _ => (false, null),
      };

  static String? _cause(Object error, int depth) {
    if (depth > _maxCauseDepth) return null;
    final (isWrapper, inner) = _unwrap(error);
    if (isWrapper) return inner == null ? null : _cause(inner, depth + 1);
    return switch (error) {
      ClientException(:final statusCode, :final originalError) =>
        statusCode > 0
            ? 'HTTP_$statusCode'
            : originalError == null
                ? 'NO_RESPONSE'
                : _cause(originalError, depth + 1),
      DioException() => _dioCause(error, depth),
      TimeoutException() => 'TIMEOUT',
      HandshakeException() || TlsException() || CertificateException() => 'TLS',
      SocketException(:final message)
          when message.toLowerCase().contains('host lookup') =>
        'DNS',
      SocketException() || HttpException() => 'UNREACHABLE',
      // A bare FormatException at the top level is already named by its own
      // ERR_FormatException base; nested, it is the compatibility mismatch.
      FormatException() => depth == 0 ? null : 'FORMAT',
      _ => depth == 0 ? null : 'OTHER_${error.runtimeType}',
    };
  }

  static String? _dioCause(DioException error, int depth) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'TIMEOUT';
      case DioExceptionType.badCertificate:
        return 'TLS';
      case DioExceptionType.badResponse:
        return 'HTTP_${error.response?.statusCode ?? 0}';
      default:
        if (error.response != null) return 'BAD_RESPONSE';
        final inner = error.error;
        return inner == null ? 'NO_RESPONSE' : _cause(inner, depth + 1);
    }
  }
}
