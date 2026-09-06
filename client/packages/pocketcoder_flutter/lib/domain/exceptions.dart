/// Base exception for all domain exceptions.
abstract class DomainException implements Exception {
  final String message;
  final dynamic cause;

  DomainException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message';
}

/// Authentication-related exceptions.
class AuthException extends DomainException {
  AuthException(super.message, [super.cause]);

  factory AuthException.loginFailed([dynamic cause]) =>
      AuthException('Login failed', cause);
  factory AuthException.notAuthenticated([dynamic cause]) =>
      AuthException('User not authenticated', cause);
  factory AuthException.tokenExpired([dynamic cause]) =>
      AuthException('Authentication token expired', cause);
}

/// Chat-related exceptions.
class ChatException extends DomainException {
  ChatException(super.message, [super.cause]);

  factory ChatException.fetchFailed([dynamic cause]) =>
      ChatException('Failed to fetch chat', cause);
  factory ChatException.sendFailed([dynamic cause]) =>
      ChatException('Failed to send message', cause);
  factory ChatException.notFound([dynamic cause]) =>
      ChatException('Chat not found', cause);
}

/// Permission-related exceptions.
class PermissionException extends DomainException {
  PermissionException(super.message, [super.cause]);

  factory PermissionException.fetchFailed([dynamic cause]) =>
      PermissionException('Failed to fetch permissions', cause);
  factory PermissionException.updateFailed([dynamic cause]) =>
      PermissionException('Failed to update permission', cause);
}

/// AI-related exceptions.
class AiException extends DomainException {
  AiException(super.message, [super.cause]);

  factory AiException.fetchFailed([dynamic cause]) =>
      AiException('Failed to fetch AI resources', cause);
  factory AiException.saveFailed([dynamic cause]) =>
      AiException('Failed to save AI configuration', cause);
}

/// Tool-permissions-related exceptions.
class ToolPermissionsException extends DomainException {
  ToolPermissionsException(super.message, [super.cause]);

  factory ToolPermissionsException.fetchFailed([dynamic cause]) =>
      ToolPermissionsException('Failed to fetch tool permissions', cause);
  factory ToolPermissionsException.updateFailed([dynamic cause]) =>
      ToolPermissionsException('Failed to update tool permissions', cause);
}

class BillingException extends DomainException {
  BillingException(super.message, [super.cause]);

  factory BillingException.restoreFailed([dynamic cause]) =>
      BillingException('Failed to restore purchases', cause);
}

/// Generic repository exceptions.
class RepositoryException extends DomainException {
  RepositoryException(super.message, [super.cause]);

  factory RepositoryException.fetchFailed([dynamic cause]) =>
      RepositoryException('Failed to fetch data', cause);
  factory RepositoryException.updateFailed([dynamic cause]) =>
      RepositoryException('Failed to update data', cause);
}

/// MCP-related exceptions.
class McpException extends DomainException {
  McpException(super.message, [super.cause]);
}

/// OAuth-flow-specific exceptions from McpOAuthService. `isCancelled` lets
/// callers (McpCubit) distinguish "user dismissed the browser sheet" (not
/// an error state — see the spec's Component 2 failure-mode list) from a
/// genuine failure.
class McpOAuthException extends DomainException {
  final bool isCancelled;

  McpOAuthException(super.message, [super.cause]) : isCancelled = false;

  McpOAuthException._(String message, {this.isCancelled = false, Object? cause})
      : super(message, cause);

  factory McpOAuthException.cancelled() =>
      McpOAuthException._('User cancelled the OAuth flow', isCancelled: true);
  factory McpOAuthException.unknownProvider(String provider) =>
      McpOAuthException._('Unknown OAuth provider: $provider');
  factory McpOAuthException.providerError(String error) =>
      McpOAuthException._('Provider returned an error: $error');
  factory McpOAuthException.claimFailed([dynamic cause]) =>
      McpOAuthException._('Failed to claim OAuth token', cause: cause);
  factory McpOAuthException.stateMismatch() =>
      McpOAuthException._('OAuth state mismatch — possible spoofed callback',
          isCancelled: false);
}

/// Observability-related exceptions.
class ObservabilityException extends DomainException {
  ObservabilityException(super.message, [super.cause]);
}

/// Skills-related exceptions.
class SkillsException extends DomainException {
  SkillsException(super.message, [super.cause]);
}

/// Scheduler-related exceptions.
class SchedulerException extends DomainException {
  SchedulerException(super.message, [super.cause]);
}

/// Live-activity-related exceptions.
class LiveActivityException extends DomainException {
  LiveActivityException(super.message, [super.cause]);
}

/// Files-related exceptions.
class FilesException extends DomainException {
  FilesException(super.message, [super.cause]);

  factory FilesException.httpError(int statusCode) =>
      FilesException('Request failed with status $statusCode');
  factory FilesException.noAuthToken() =>
      FilesException('No auth token available');
}
