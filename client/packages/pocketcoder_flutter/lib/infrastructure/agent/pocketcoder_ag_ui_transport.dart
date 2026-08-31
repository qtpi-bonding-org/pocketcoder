import 'dart:async';

import 'package:acp_dart/acp_dart.dart';
import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:collection/collection.dart';

import '../../domain/agent/elicitation_response.dart';
import 'agent_chat_repository.dart';

/// Synthetic marker this transport emits itself before replaying a
/// shrunk cache, since AgentChatRepository.ingestOnce consumes the real
/// pocketcoder:sync marker before it ever reaches the cache. Recognized by
/// ConversationReducer's isReplaceMarker (Task 3) identically to the real
/// wire marker — the reducer doesn't know or care which produced it.
BaseEvent _syntheticResetMarker() =>
    CustomEvent(name: 'pocketcoder:sync', value: {'mode': 'replace'});

class PocketcoderAgUiTransport implements IAgUiTransport {
  PocketcoderAgUiTransport(this._repository, {required String chatId})
      : _chatId = chatId;

  final AgentChatRepository _repository;
  final String _chatId;
  final _events = StreamController<BaseEvent>.broadcast();
  StreamSubscription<List<BaseEvent>>? _rawSub;
  List<String> _seenJson = const [];

  @override
  Stream<BaseEvent> get events {
    _rawSub ??= _repository.watchRawEvents(_chatId).listen((all) {
      // The cache upserts by (chatId, seq): a reconnect can replay an
      // EXISTING seq with corrected/finalized content, leaving the row
      // count unchanged. Diffing on length alone missed that entirely --
      // compare serialized content so a same-length content change is
      // caught too, not just growth/shrink.
      final serialized = all.map((event) => event.toJsonString()).toList();
      if (serialized.length > _seenJson.length &&
          const ListEquality<String>()
              .equals(serialized.sublist(0, _seenJson.length), _seenJson)) {
        // Pure append: everything already seen is an unchanged prefix.
        for (final event in all.skip(_seenJson.length)) {
          _events.add(event);
        }
      } else if (!const ListEquality<String>().equals(serialized, _seenJson)) {
        // Anything else that actually changed -- a shrink (cold-replay
        // reset) or a same-length content correction at an existing seq.
        // Emit a synthesized reset marker FIRST so any downstream
        // ConversationReducer actually resets, then replay the full
        // current snapshot.
        _events.add(_syntheticResetMarker());
        for (final event in all) {
          _events.add(event);
        }
      }
      _seenJson = serialized;
    });
    return _events.stream;
  }

  @override
  Future<void> sendMessage(String text,
      {List<AgUiContextItem> context = const [], String? messageId}) async {
    // pocketcoder's sendPrompt has no context-item support yet (that's a
    // newer AgUiChat capability) — dropped like submitToolResult below,
    // satisfying IAgUiTransport's now-wider interface.
    await _repository.sendPrompt(_chatId, text, messageId: messageId);
  }

  @override
  Future<void> cancel() async {
    await _repository.cancel(_chatId);
  }

  @override
  Future<void> respondPermission(String callId,
      {String? optionId, bool cancelled = false}) async {
    await _repository.respondPermission(_chatId, callId,
        optionId: optionId, cancelled: cancelled);
  }

  @override
  Future<void> respondElicitation(
      String elicitationId, Map<String, dynamic> response) async {
    final decoded = switch (response['action']) {
      'accept' => ElicitationResponse.accept(
          response['content'] as Map<String, dynamic>? ?? const {}),
      'decline' => const ElicitationResponse.decline(),
      _ => const ElicitationResponse.cancel(),
    };
    await _repository.respondElicitation(_chatId, elicitationId, decoded);
  }

  @override
  Future<void> submitToolResult(String callId, String resultJson) async {
    // pocketcoder has no client-executed-tool convention today (that's an
    // episutra-only concept, see ACP request/response modeling spec) — no
    // backend endpoint exists to submit one against, so this is a
    // deliberate no-op that satisfies IAgUiTransport's now-wider interface.
  }

  @override
  Future<void> setMode(String modeId) async {
    await _repository.setMode(_chatId, modeId);
  }

  @override
  Future<void> setConfigOption(String optionId, String value) async {
    await _repository.setConfigOption(
      _chatId,
      SetSessionConfigOptionRequest(
        // Required by the ACP DTO but intentionally excluded from the
        // generated REST model; the server resolves the session by chatId.
        sessionId: '',
        configId: optionId,
        value: value,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _rawSub?.cancel();
    _rawSub = null;
    await _events.close();
  }
}
