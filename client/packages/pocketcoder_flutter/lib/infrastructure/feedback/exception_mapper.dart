import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/application/agent/provider_reauthentication_required.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
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
      BillingException() => _mapBillingException(exception),
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
    // tryMethod wraps every AuthRepository failure's real cause in
    // exception.cause as a SafeExceptionCause; exception.message is only a
    // privacy-safe label.
    final original = switch (exception.cause) {
      SafeExceptionCause(:final originalException) => originalException,
      final other => other,
    };
    if (original is ClientException) {
      if (original.statusCode == 400 ||
          original.statusCode == 401 ||
          original.statusCode == 403) {
        return const MessageKey.error('auth.login.failed');
      }
      // statusCode 0 (no HTTP response), 5xx, 408/425/429: transport/server
      // trouble, not a credentials verdict. Say which kind when the cause
      // tells us, so a screenshot from a device we can't reproduce on is
      // diagnosable instead of just "Network error".
      return _mapTransportFailure(
        cause: original.originalError,
        statusCode: original.statusCode,
      );
    }
    if (original is DioException) {
      return _mapDioFailure(original);
    }
    if (original is FormatException) {
      // From verifyServerCompatibility(): reached fine, contract mismatch.
      return const MessageKey.error('auth.server.incompatible');
    }
    return switch (exception.message) {
      String msg when msg.toLowerCase().contains('login') =>
        const MessageKey.error('auth.login.failed'),
      String msg when msg.contains('not authenticated') =>
        const MessageKey.error('auth.not.authenticated'),
      String msg when msg.contains('token') =>
        const MessageKey.error('auth.token.expired'),
      _ => const MessageKey.error('auth.error'),
    };
  }

  MessageKey _mapDioFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const MessageKey.error('auth.server.timeout');
      case DioExceptionType.badCertificate:
        return const MessageKey.error('auth.server.tls');
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status >= 500) return const MessageKey.error('auth.server.error');
        if (status == 401 || status == 403) {
          return const MessageKey.error('auth.login.failed');
        }
        // Reached a web server that doesn't speak PocketCoder's API (a 404 on
        // the compatibility route, a redirect, a proxy's 405): not a
        // transport problem.
        return const MessageKey.error('auth.server.incompatible');
      default:
        // An answer we couldn't parse (captive portal, wrong server).
        if (error.response != null) {
          return const MessageKey.error('auth.server.incompatible');
        }
        return _mapTransportFailure(cause: error.error, statusCode: 0);
    }
  }

  MessageKey _mapTransportFailure({
    required Object? cause,
    required int statusCode,
  }) {
    if (statusCode >= 500) return const MessageKey.error('auth.server.error');
    return switch (cause) {
      TimeoutException() => const MessageKey.error('auth.server.timeout'),
      HandshakeException() ||
      TlsException() ||
      CertificateException() =>
        const MessageKey.error('auth.server.tls'),
      SocketException(:final message)
          when message.toLowerCase().contains('host lookup') =>
        const MessageKey.error('auth.server.dns'),
      SocketException() ||
      HttpException() =>
        const MessageKey.error('auth.server.unreachable'),
      null => const MessageKey.error('error.network'),
      final other => MessageKey.error(
          'auth.server.unexpected', {'detail': other.runtimeType.toString()}),
    };
  }

  MessageKey? _mapChatException(ChatException exception) {
    return switch (exception.message) {
      String msg when msg.contains('fetch') =>
        const MessageKey.error('chat.fetch.failed'),
      String msg when msg.contains('send') =>
        const MessageKey.error('chat.send.failed'),
      String msg when msg.contains('not found') =>
        const MessageKey.error('chat.not.found'),
      _ => const MessageKey.error('chat.error'),
    };
  }

  MessageKey? _mapChatListException(ChatListException exception) {
    return const MessageKey.error('chat.list.error');
  }

  MessageKey? _mapPermissionException(PermissionException exception) {
    return switch (exception.message) {
      String msg when msg.contains('fetch') =>
        const MessageKey.error('permission.fetch.failed'),
      String msg when msg.contains('update') =>
        const MessageKey.error('permission.update.failed'),
      _ => const MessageKey.error('permission.error'),
    };
  }

  MessageKey? _mapAiException(AiException exception) {
    return switch (exception.message) {
      String msg when msg.contains('fetch') =>
        const MessageKey.error('ai.fetch.failed'),
      String msg when msg.contains('save') =>
        const MessageKey.error('ai.save.failed'),
      _ => const MessageKey.error('ai.error'),
    };
  }

  MessageKey? _mapToolPermissionsException(ToolPermissionsException exception) {
    return switch (exception.message) {
      String msg when msg.contains('fetch') =>
        const MessageKey.error('tool.permissions.fetch.failed'),
      String msg when msg.contains('update') =>
        const MessageKey.error('tool.permissions.update.failed'),
      _ => const MessageKey.error('tool.permissions.error'),
    };
  }

  MessageKey? _mapBillingException(BillingException exception) {
    return switch (exception.message) {
      String msg when msg.contains('restore') =>
        const MessageKey.error('billing.restore.failed'),
      _ => const MessageKey.error('billing.error'),
    };
  }
}
