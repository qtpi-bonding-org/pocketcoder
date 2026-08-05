import 'dart:async';

import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';

import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/pocketcoder_ag_ui_transport.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'chat_state.dart';

@injectable
class ChatCubit extends AppCubit<ChatState> {
  ChatCubit(this._repository) : super(const ChatState());

  final AgentChatRepository _repository;
  PocketcoderAgUiTransport? _transport;
  ConversationReducer? _reducer;
  StreamSubscription<BaseEvent>? _eventSub;
  int _generation = 0;

  @override
  Future<void> close() {
    _generation++;
    _eventSub?.cancel();
    _transport?.dispose();
    return super.close();
  }

  static const _reconnectDelay = Duration(milliseconds: 200);
  static const _maxReconnectDelay = Duration(seconds: 5);

  /// Consecutive ingest failures before a hung reconnect loop is surfaced to
  /// the UI. Below this, a blip retries silently; at/above it, the user sees
  /// a real error instead of an indefinite "thinking" spinner tied to
  /// [UiFlowStatus.loading] never resolving (see [_ingestForever]).
  static const _visibleFailureThreshold = 3;

  void open(String chatId) {
    _generation++;
    final myGeneration = _generation;

    _eventSub?.cancel();
    _transport?.dispose();
    _reducer = ConversationReducer();
    _transport = PocketcoderAgUiTransport(_repository, chatId: chatId);

    emit(state.copyWith(
      chatId: chatId,
      status: UiFlowStatus.loading,
      lastOperation: AgentChatOperation.open,
    ));

    _eventSub = _transport!.events.listen(
      (event) {
        if (myGeneration != _generation) return;
        _reducer!.apply(event);
        emit(state.copyWith(
            conversation: _reducer!.current, status: UiFlowStatus.success));
      },
      onError: (Object e) {
        if (myGeneration != _generation) return;
        unawaited(pocketCoderDiagnosticCapture.capture(
          error: e,
          source: 'ChatCubit',
          operation: 'eventsStream',
        ));
        logError('🤖 [ChatCubit] events error', e);
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );

    unawaited(_ingestForever(chatId, myGeneration));
  }

  Future<void> _ingestForever(String chatId, int myGeneration) async {
    var delay = _reconnectDelay;
    var consecutiveFailures = 0;
    while (myGeneration == _generation) {
      try {
        final cursor = await _repository.cursorFor(chatId);
        await _repository.ingestOnce(chatId, cursor: cursor);
        consecutiveFailures = 0;
        delay = _reconnectDelay;
      } catch (e) {
        if (myGeneration != _generation) return;
        unawaited(pocketCoderDiagnosticCapture.capture(
          error: e,
          source: 'ChatCubit',
          operation: 'ingestStream',
        ));
        logError('🤖 [ChatCubit] ingest error, reconnecting', e);
        consecutiveFailures++;
        // Fires once on crossing the threshold, not on every retry after
        // it, so the error snackbar doesn't spam while backoff continues.
        if (consecutiveFailures == _visibleFailureThreshold) {
          emit(state.copyWith(error: e, status: UiFlowStatus.failure));
        }
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(
              _reconnectDelay.inMilliseconds,
              _maxReconnectDelay.inMilliseconds),
        );
      }
      if (myGeneration != _generation) return;
      await Future<void>.delayed(delay);
    }
  }

  Future<void> sendPrompt(String text) async {
    final chatId = state.chatId;
    final transport = _transport;
    if (chatId == null || transport == null) {
      logWarning('🤖 [ChatCubit] sendPrompt called before open()');
      return;
    }
    await tryOperation(() async {
      await transport.sendMessage(text);
      return state.copyWith(
          status: UiFlowStatus.success,
          lastOperation: AgentChatOperation.sendPrompt);
    });
  }

  Future<void> cancel() async {
    final transport = _transport;
    if (transport == null) return;
    await tryOperation(() async {
      await transport.cancel();
      return state.copyWith(
          status: UiFlowStatus.success,
          lastOperation: AgentChatOperation.cancel);
    });
  }
}
