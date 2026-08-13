// Up-channel actions: every method builds an acp_dart request type, calls
// `.toJson()`, strips the `sessionId` key (c1 injects it from the path —
// spec §5.3, "REST bodies = verbatim ACP payloads minus sessionId"), and
// POSTs through the injected PocketBase. c1's response statuses map to the
// typed failures in [AgentActionFailure] (spec §10).
import 'package:acp_dart/acp_dart.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';

/// Typed failures for the up-channel, mapped from c1's documented HTTP
/// statuses (spec §10): 400 malformed/option-not-offered, 401 unauthenticated,
/// 404 chat/unknown-request/not-owner, 409 run-active, 503 agent-not-configured.
sealed class AgentActionFailure implements Exception {
  const AgentActionFailure(this.message);
  final String message;
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

/// Placeholder sessionId used only to satisfy acp_dart's required
/// constructor parameter; every `toJson()` result below has this key
/// stripped before the body is sent — c1 derives the real session from the
/// chatId path segment, and Flutter never sees `acp_session_id` (spec §12).
const elidedSessionId = '';

@lazySingleton
class AgentActionsApi {
  AgentActionsApi(this._pb);

  final PocketBase _pb;

  Map<String, dynamic> _withoutSessionId(Map<String, dynamic> json) {
    return {...json}..remove('sessionId');
  }

  Future<void> _postVoid(String path, Map<String, dynamic> body) async {
    try {
      await _pb.send<dynamic>(path, method: 'POST', body: body);
    } on ClientException catch (e) {
      throw _mapFailure(e);
    }
  }

  Future<T> _postJson<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final result = await _pb.send<dynamic>(path, method: 'POST', body: body);
      return parse(result as Map<String, dynamic>);
    } on ClientException catch (e) {
      throw _mapFailure(e);
    }
  }

  AgentActionFailure _mapFailure(ClientException e) {
    final message = (e.response['message'] as String?) ?? e.toString();
    switch (e.statusCode) {
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
  Future<String> prompt(String chatId, String text) {
    final req = PromptRequest(
      sessionId: elidedSessionId,
      prompt: [TextContentBlock(text: text)],
    );
    return _postJson<String>(
      ApiEndpoints.agentPrompt(chatId),
      _withoutSessionId(req.toJson()),
      (json) => json['runId'] as String,
    );
  }

  /// POST `session/cancel`, `{}`.
  Future<void> cancel(String chatId) {
    return _postVoid(
      ApiEndpoints.agentCancel(chatId),
      const {},
    );
  }

  /// POST `session/set_mode` ← `SetSessionModeRequest`.
  Future<void> setMode(String chatId, String modeId) {
    final req = SetSessionModeRequest(
      sessionId: elidedSessionId,
      modeId: modeId,
    );
    return _postVoid(
      ApiEndpoints.agentSetMode(chatId),
      _withoutSessionId(req.toJson()),
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
    return _postVoid(
      ApiEndpoints.agentSetConfigOption(chatId),
      _withoutSessionId(req.toJson()),
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
    final req = RequestPermissionResponse(outcome: outcome);
    return _postVoid(
      ApiEndpoints.agentPermission(chatId, requestId),
      _withoutSessionId(req.toJson()),
    );
  }

  /// POST `session/elicitation/{elicitationId}` ← the hand-authored
  /// [ElicitationResponse] DTO (acp_dart ships none — plan Task 9 / spec §6.2).
  Future<void> respondElicitation(
    String chatId,
    String elicitationId,
    ElicitationResponse resp,
  ) {
    return _postVoid(
      ApiEndpoints.agentElicitation(chatId, elicitationId),
      resp.toJson(),
    );
  }
}
