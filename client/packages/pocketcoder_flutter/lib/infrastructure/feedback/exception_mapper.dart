import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/agent/provider_reauthentication_required.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/exceptions/chat_list_exception.dart';

/// Global exception mapper for the application.
///
/// Maps all application exceptions to user-friendly message keys
/// that can be localized and displayed to users.
@LazySingleton(as: IExceptionKeyMapper)
class AppExceptionKeyMapper implements IExceptionKeyMapper {
  @override
  MessageKey? map(Object exception) {
    return switch (exception) {
      AuthException() => _mapAuthException(exception),
      ChatException() => _mapChatException(exception),
      ChatListException() => _mapChatListException(exception),
      PermissionException() => _mapPermissionException(exception),
      AiException() => _mapAiException(exception),
      ToolPermissionsException() => _mapToolPermissionsException(exception),
      ProviderReauthenticationRequired() =>
        const MessageKey.error('provider.reauthentication.required'),
      // Domain exceptions with no dedicated copy yet -- fall back to the
      // generic error key rather than null, which used to leak
      // DomainException's raw '$runtimeType: $message' toString() (e.g.
      // "ObservabilityException: failed to fetch traces") straight to the
      // user via UiFlowListener's own fallback.
      RepositoryException() ||
      McpException() ||
      ObservabilityException() ||
      SkillsException() ||
      SchedulerException() ||
      FilesException() =>
        MessageKey.genericError,
      _ => null,
    };
  }

  MessageKey? _mapAuthException(AuthException exception) {
    return switch (exception.message) {
      String msg when msg.contains('Login') => const MessageKey.error('auth.loginFailed'),
      String msg when msg.contains('not authenticated') => const MessageKey.error('auth.notAuthenticated'),
      String msg when msg.contains('token') => const MessageKey.error('auth.tokenExpired'),
      _ => const MessageKey.error('auth.error'),
    };
  }

  MessageKey? _mapChatException(ChatException exception) {
    return switch (exception.message) {
      String msg when msg.contains('fetch') => const MessageKey.error('chat.fetchFailed'),
      String msg when msg.contains('send') => const MessageKey.error('chat.sendFailed'),
      String msg when msg.contains('not found') => const MessageKey.error('chat.notFound'),
      _ => const MessageKey.error('chat.error'),
    };
  }

  MessageKey? _mapChatListException(ChatListException exception) {
    return const MessageKey.error('chatList.error');
  }

  MessageKey? _mapPermissionException(PermissionException exception) {
    return switch (exception.message) {
      String msg when msg.contains('fetch') => const MessageKey.error('permission.fetchFailed'),
      String msg when msg.contains('update') => const MessageKey.error('permission.updateFailed'),
      _ => const MessageKey.error('permission.error'),
    };
  }

  MessageKey? _mapAiException(AiException exception) {
    return switch (exception.message) {
      String msg when msg.contains('fetch') => const MessageKey.error('ai.fetchFailed'),
      String msg when msg.contains('save') => const MessageKey.error('ai.saveFailed'),
      _ => const MessageKey.error('ai.error'),
    };
  }

  MessageKey? _mapToolPermissionsException(ToolPermissionsException exception) {
    return switch (exception.message) {
      String msg when msg.contains('fetch') => const MessageKey.error('toolPermissions.fetchFailed'),
      String msg when msg.contains('update') => const MessageKey.error('toolPermissions.updateFailed'),
      _ => const MessageKey.error('toolPermissions.error'),
    };
  }
}
