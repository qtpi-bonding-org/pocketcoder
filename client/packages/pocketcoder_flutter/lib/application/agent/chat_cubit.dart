import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';

import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'chat_state.dart';

/// Owns one chat's AG-UI stream lifecycle: connect at the cached cursor,
/// reconnect on drop with a fresh cursor (spec §5.1 — "reconnect is
/// explicitly driven by the client"), and reduce the cache into [ChatState]
/// via [AgentChatRepository.watch]. Actions ([sendPrompt], [cancel]) never
/// mutate local state directly — their effect always arrives back through
/// the watched stream once c1/Goose emits it.
@injectable
class ChatCubit extends AppCubit<ChatState> {
  ChatCubit(this._repository) : super(const ChatState());

  final AgentChatRepository _repository;

  StreamSubscription? _watchSub;
  int _generation = 0;

  @override
  Future<void> close() {
    _generation++;
    _watchSub?.cancel();
    return super.close();
  }

  /// Starts watching [chatId]: subscribes the reduced Conversation view and
  /// kicks off the reconnect-forever ingest loop. Calling this again with a
  /// different chatId tears down the previous subscription/loop first.
  void open(String chatId) {
    _generation++;
    final myGeneration = _generation;

    _watchSub?.cancel();
    emit(state.copyWith(
      chatId: chatId,
      status: UiFlowStatus.loading,
      lastOperation: AgentChatOperation.open,
    ));

    _watchSub = _repository.watch(chatId).listen(
      (conversation) {
        if (myGeneration != _generation) return;
        emit(state.copyWith(
          conversation: conversation,
          status: UiFlowStatus.success,
        ));
      },
      onError: (Object e) {
        if (myGeneration != _generation) return;
        logError('🤖 [ChatCubit] watch($chatId) error: $e');
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );

    unawaited(_ingestForever(chatId, myGeneration));
  }

  /// Connects, ingests until the connection drops (or errors), then
  /// reconnects with a fresh cursor (`AgentCacheDb.maxSeq`) — forever, until
  /// a newer [open] call (or [close]) bumps the generation. A short delay
  /// between attempts is a real macrotask yield (not just a microtask), so
  /// a connection that ends instantly (e.g. a fake in tests, or a server
  /// that drops the connection immediately) can't busy-loop and starve the
  /// event loop; it also functions as a minimal reconnect backoff so a
  /// persistently failing connection doesn't hammer c1.
  static const _reconnectDelay = Duration(milliseconds: 200);

  Future<void> _ingestForever(String chatId, int myGeneration) async {
    while (myGeneration == _generation) {
      try {
        final cursor = await _repository.cursorFor(chatId);
        await _repository.ingestOnce(chatId, cursor: cursor);
      } catch (e) {
        if (myGeneration != _generation) return;
        logError('🤖 [ChatCubit] ingest($chatId) error, reconnecting: $e');
      }
      if (myGeneration != _generation) return;
      await Future<void>.delayed(_reconnectDelay);
    }
  }

  Future<void> sendPrompt(String text) async {
    final chatId = state.chatId;
    if (chatId == null) {
      logWarning('🤖 [ChatCubit] sendPrompt called before open()');
      return;
    }
    await tryOperation(() async {
      await _repository.sendPrompt(chatId, text);
      return state.copyWith(
        status: UiFlowStatus.success,
        lastOperation: AgentChatOperation.sendPrompt,
      );
    });
  }

  Future<void> cancel() async {
    final chatId = state.chatId;
    if (chatId == null) return;
    await tryOperation(() async {
      await _repository.cancel(chatId);
      return state.copyWith(
        status: UiFlowStatus.success,
        lastOperation: AgentChatOperation.cancel,
      );
    });
  }
}
