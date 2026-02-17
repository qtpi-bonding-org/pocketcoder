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

/// Whitelist-related exceptions.
class WhitelistException extends DomainException {
  WhitelistException(super.message, [super.cause]);

  factory WhitelistException.fetchFailed([dynamic cause]) =>
      WhitelistException('Failed to fetch whitelist', cause);
  factory WhitelistException.updateFailed([dynamic cause]) =>
      WhitelistException('Failed to update whitelist', cause);
}