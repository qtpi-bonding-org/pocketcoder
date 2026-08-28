// Agent actions use generated OpenAPI request models and operations. ACP-only
// unions are converted at this boundary before they reach the generated API.
import 'package:acp_dart/acp_dart.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;

import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';

/// Typed failures for the up-channel, mapped from c1's documented HTTP
/// statuses (spec §10): 400 malformed/option-not-offered, 401 unauthenticated,
/// 404 chat/unknown-request/not-owner, 409 run-active, 503 agent-not-configured.
sealed class AgentActionFailure implements Exception {
  const AgentActionFailure(this.message);
  final String message;

  // Without this, an unmapped AgentActionFailure reaching UiFlowListener's
  // fallback (no IExceptionKeyMapper entry -- see AppExceptionKeyMapper)
  // renders as Dart's default Object.toString(), "Instance of
  // 'UnknownAgentActionFailure'", directly in the UI -- confirmed live.
  @override
  String toString() => message;
}

class BadRequestFailure extends AgentActionFailure {
  const BadRequestFailure(super.message);
}

class UnauthenticatedFailure extends AgentActionFailure {
  const UnauthenticatedFailure(super.message);
}

class NotFoundFailure extends AgentActionFailure {
  const NotFoundFailure(super.message);
}

class RunInProgressFailure extends AgentActionFailure {
  const RunInProgressFailure(super.message);
}

class AgentUnavailableFailure extends AgentActionFailure {
  const AgentUnavailableFailure(super.message);
}

/// Anything else (network error, unexpected status) — surfaced so callers
/// don't have to guess at a message shape that doesn't apply.
class UnknownAgentActionFailure extends AgentActionFailure {
  const UnknownAgentActionFailure(super.message);
}

@lazySingleton
class AgentActionsApi {
  AgentActionsApi(this._api);

  final PocketCoderApiClient _api;

  // The generated built_value callbacks are nullable under Flutter stable's
  // analyzer but non-nullable under the newer local analyzer. Their builder
  // classes are also intentionally not exported by pocketcoder_api. Keep both
  // generator-version details contained at this boundary.
  static void _writeTextPrompt(
    dynamic builder,
    String text,
    String? messageId,
  ) {
    final prompt = builder?.prompt;
    if (prompt == null) {
      throw StateError('Prompt request builder is unavailable');
    }
    prompt.add(
      generated.ContentBlock(
        (block) => _writeTextContentBlock(block, text),
      ),
    );
    if (messageId != null) {
      builder.messageId = messageId;
    }
  }

  static void _writeTextContentBlock(
    dynamic builder,
    String text,
  ) {
    if (builder == null) {
      throw StateError('Prompt content builder is unavailable');
    }
    builder
      ..type = 'text'
      ..text = text;
  }

  static void _writeMode(
    dynamic builder,
    String modeId,
  ) {
    if (builder == null) {
      throw StateError('Mode request builder is unavailable');
    }
    builder.modeId = modeId;
  }

  static void _writeConfigOption(
    dynamic builder,
    SetSessionConfigOptionRequest request,
  ) {
    final configId = _optionalString(request.configId);
    final value = _optionalString(request.value);
    if (builder == null || configId == null || value == null) {
      throw StateError('Config option request is incomplete');
    }
    builder
      ..configId = configId
      ..value = value;
  }

  static String? _optionalString(Object? value) =>
      value is String ? value : null;

  Future<void> _callVoid(Future<void> Function() operation) async {
    try {
      await operation();
    } on DioException catch (e) {
      throw _mapFailure(e);
    }
  }

  Future<T> _call<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DioException catch (e) {
      throw _mapFailure(e);
    }
  }

  AgentActionFailure _mapFailure(DioException e) {
    final data = e.response?.data;
    final message = data is Map<String, dynamic>
        ? data['message'] as String? ?? e.message ?? e.toString()
        : e.message ?? e.toString();
    final statusCode = e.response?.statusCode;
    AppLogger.error('AgentActionsApi request failed', e, e.stackTrace);
    logDebug('AgentActionsApi request failed', {
      'statusCode': statusCode,
      'path': e.requestOptions.path,
      'method': e.requestOptions.method,
      'dioErrorType': e.type.name,
      'responseData': data,
      'message': message,
    });
    switch (statusCode) {
      case 400:
        return BadRequestFailure(message);
      case 401:
        return UnauthenticatedFailure(message);
      case 404:
        return NotFoundFailure(message);
      case 409:
        return RunInProgressFailure(message);
      case 503:
        return AgentUnavailableFailure(message);
      default:
        return UnknownAgentActionFailure(message);
    }
  }

  /// POST `session/prompt` with a single text ContentBlock. Returns the
  /// server-assigned `runId`. Throws [RunInProgressFailure] (409) if a run
  /// is already active for this chat.
  Future<String> prompt(String chatId, String text, {String? messageId}) {
    final request = generated.PromptRequest(
      (builder) => _writeTextPrompt(builder, text, messageId),
    );
    return _call(
      () async {
        final response = await _api.agent.promptChat(
          chatId: chatId,
          promptRequest: request,
        );
        final runId = response.data?.runId;
        if (runId == null || runId.isEmpty) {
          throw const UnknownAgentActionFailure('Missing agent run id');
        }
        return runId;
      },
    );
  }

  /// POST `session/cancel`, `{}`.
  Future<void> cancel(String chatId) {
    return _callVoid(
      () async {
        await _api.agent.cancelChatSession(chatId: chatId);
      },
    );
  }

  /// POST `session/set_mode` ← `SetSessionModeRequest`.
  Future<void> setMode(String chatId, String modeId) {
    final request = generated.ModeRequest(
      (builder) => _writeMode(builder, modeId),
    );
    return _callVoid(
      () async {
        await _api.agent.setChatMode(
          chatId: chatId,
          modeRequest: request,
        );
      },
    );
  }

  /// POST `session/set_config_option` ← `SetSessionConfigOptionRequest`.
  /// Note: acp_dart 0.4.0's SetSessionConfigOptionRequest carries
  /// `configId`/`value` (both plain strings), not a Boolean/Select
  /// discriminated union — see the Task 5 commit note.
  Future<void> setConfigOption(
    String chatId,
    SetSessionConfigOptionRequest req,
  ) {
    final request = generated.ConfigOptionRequest(
      (builder) => _writeConfigOption(builder, req),
    );
    return _callVoid(
      () async {
        await _api.agent.setChatConfigOption(
          chatId: chatId,
          configOptionRequest: request,
        );
      },
    );
  }

  /// POST `session/request_permission/{requestId}` ← `RequestPermissionResponse`
  /// (`selected` with `optionId`, or `cancelled`).
  Future<void> respondPermission(
    String chatId,
    String requestId, {
    String? optionId,
    bool cancelled = false,
  }) {
    final outcome = cancelled || optionId == null
        ? CancelledOutcome()
        : SelectedOutcome(optionId: optionId);
    final request = RequestPermissionResponse(outcome: outcome).toJson()
      ..remove('sessionId');
    return _callVoid(
      () async {
        await _api.agent.respondToPermission(
          chatId: chatId,
          id: requestId,
          requestBody: PocketCoderApiClient.encodeJson(request),
        );
      },
    );
  }

  /// POST `session/elicitation/{elicitationId}` ← the hand-authored
  /// [ElicitationResponse] DTO (acp_dart ships none — plan Task 9 / spec §6.2).
  Future<void> respondElicitation(
    String chatId,
    String elicitationId,
    ElicitationResponse resp,
  ) {
    return _callVoid(
      () async {
        await _api.agent.respondToElicitation(
          chatId: chatId,
          id: elicitationId,
          requestBody: PocketCoderApiClient.encodeJson(resp.toJson()),
        );
      },
    );
  }
}
