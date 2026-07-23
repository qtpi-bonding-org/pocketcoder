import 'dart:async';

import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';

import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
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
        emit(state.copyWith(conversation: _reducer!.current, status: UiFlowStatus.success));
      },
      onError: (Object e) {
        if (myGeneration != _generation) return;
        logError('🤖 [ChatCubit] events($chatId) error: $e');
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );

    unawaited(_ingestForever(chatId, myGeneration));
  }

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
    final transport = _transport;
    if (chatId == null || transport == null) {
      logWarning('🤖 [ChatCubit] sendPrompt called before open()');
      return;
    }
    await tryOperation(() async {
      await transport.sendMessage(text);
      return state.copyWith(status: UiFlowStatus.success, lastOperation: AgentChatOperation.sendPrompt);
    });
  }

  Future<void> cancel() async {
    final transport = _transport;
    if (transport == null) return;
    await tryOperation(() async {
      await transport.cancel();
      return state.copyWith(status: UiFlowStatus.success, lastOperation: AgentChatOperation.cancel);
    });
  }
}
