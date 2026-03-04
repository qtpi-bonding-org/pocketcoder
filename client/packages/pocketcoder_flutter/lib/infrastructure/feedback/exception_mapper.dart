import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';

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
      PermissionException() => _mapPermissionException(exception),
      AiException() => _mapAiException(exception),
      WhitelistException() => _mapWhitelistException(exception),
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

  MessageKey? _mapWhitelistException(WhitelistException exception) {
    return switch (exception.message) {
      String msg when msg.contains('fetch') => const MessageKey.error('whitelist.fetchFailed'),
      String msg when msg.contains('update') => const MessageKey.error('whitelist.updateFailed'),
      _ => const MessageKey.error('whitelist.error'),
    };
  }
}
