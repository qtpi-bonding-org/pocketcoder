// Wires AgentStreamClient -> AgentCacheDb (the offline mirror) and exposes
// the reduced Conversation view. The selected harness owns its history: a
// cold-replay marker replaces the cache wholesale, a
// warm frame just upserts. No direct AG-UI/ACP type leaks past this file
// except AguiEvent (already re-exported by agui_decode.dart).
import 'package:acp_dart/acp_dart.dart';
import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:injectable/injectable.dart';

import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_actions_api.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_stream_client.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agui_decode.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/cache/agent_cache_db.dart';

@lazySingleton
class AgentChatRepository {
  AgentChatRepository(this._streamClient, this._cache, this._actions);

  final AgentStreamClient _streamClient;
  final AgentCacheDb _cache;
  final AgentActionsApi _actions;

  /// Opens one SSE connection at [cursor] and ingests every frame into the
  /// cache until the connection drops (the stream completes) or errors.
  /// A `pocketcoder:sync` replace marker clears the chat's cached rows
  /// before any further frame is ingested; every other frame is an
  /// insert-or-replace upsert keyed by its seq. Callers (ChatCubit) are
  /// responsible for reconnecting — this method owns exactly one attempt.
  Future<void> ingestOnce(String chatId, {required int cursor}) async {
    await for (final frame in _streamClient.connect(chatId, cursor: cursor)) {
      if (isReplaceMarker(frame.event)) {
        await _cache.clearChat(chatId);
        continue;
      }
      await _cache.upsertEvent(
        chatId,
        frame.seq,
        frame.event.type,
        frame.rawJson,
      );
    }
  }

  /// Reactive reduced view of the chat's cached AG-UI events.
  Stream<Conversation> watch(String chatId) {
    return _cache.watchChat(chatId).map((rows) {
      final events = rows.map((row) => decodeAguiFrame(row.json).event).toList();
      return reduce(events);
    });
  }

  /// Reactive view of the chat's cached *raw* decoded events (not reduced),
  /// for PocketcoderAgUiTransport to diff against. Emits the full list on
  /// every cache change, same emission cadence as [watch] — the diffing
  /// happens in PocketcoderAgUiTransport, not here.
  Stream<List<BaseEvent>> watchRawEvents(String chatId) {
    return _cache.watchChat(chatId).map(
          (rows) => rows.map((row) => decodeAguiFrame(row.json).event).toList(),
        );
  }

  /// The SSE resume cursor: the highest seq cached for this chat, or 0 for
  /// a cold open (spec §5.1).
  Future<int> cursorFor(String chatId) async {
    return await _cache.maxSeq(chatId) ?? 0;
  }

  Future<String> sendPrompt(String chatId, String text) {
    return _actions.prompt(chatId, text);
  }

  Future<void> cancel(String chatId) {
    return _actions.cancel(chatId);
  }

  Future<void> setMode(String chatId, String modeId) {
    return _actions.setMode(chatId, modeId);
  }

  Future<void> setConfigOption(
    String chatId,
    SetSessionConfigOptionRequest req,
  ) {
    return _actions.setConfigOption(chatId, req);
  }

  Future<void> respondPermission(
    String chatId,
    String requestId, {
    String? optionId,
    bool cancelled = false,
  }) {
    return _actions.respondPermission(
      chatId,
      requestId,
      optionId: optionId,
      cancelled: cancelled,
    );
  }

  Future<void> respondElicitation(
    String chatId,
    String elicitationId,
    ElicitationResponse resp,
  ) {
    return _actions.respondElicitation(chatId, elicitationId, resp);
  }
}
