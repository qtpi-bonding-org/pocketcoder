// ElicitationCubit (plan Task 12): owns the SessionState.elicitation slice
// of one chat's reduced Conversation stream and forwards the user's
// ElicitationResponse through AgentChatRepository.respondElicitation.
// Mirrors ChatCubit's open-pattern (subscribe via repository.watch; replace
// the subscription on a subsequent open). submit() never mutates the
// elicitation map directly — the next watch() emission carries the cleared
// form.
import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';

import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'elicitation_state.dart';

@injectable
class ElicitationCubit extends AppCubit<ElicitationState> {
  ElicitationCubit(this._repository) : super(const ElicitationState());

  final AgentChatRepository _repository;

  StreamSubscription? _watchSub;
  String? _chatId;
  int _generation = 0;

  @override
  Future<void> close() {
    _generation++;
    _watchSub?.cancel();
    return super.close();
  }

  /// Starts watching [chatId]'s reduced Conversation and surfaces its
  /// `sessionState.elicitation` slice in [ElicitationState]. Calling this
  /// again with a different chatId tears down the previous subscription
  /// first.
  void open(String chatId) {
    _generation++;
    final myGeneration = _generation;
    _chatId = chatId;
    _watchSub?.cancel();
    emit(state.copyWith(
      chatId: chatId,
      status: UiFlowStatus.loading,
      lastOperation: ElicitationOperation.open,
    ));

    _watchSub = _repository.watch(chatId).listen(
      (conversation) {
        if (myGeneration != _generation) return;
        emit(state.copyWith(
          sessionState: conversation.sessionState,
          status: UiFlowStatus.success,
        ));
      },
      onError: (Object e) {
        if (myGeneration != _generation) return;
        unawaited(pocketCoderDiagnosticCapture.capture(
          error: e,
          source: 'ElicitationCubit',
          operation: 'watchStream',
        ));
        logError('🤖 [ElicitationCubit] watch error', e);
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );
  }

  /// Submits the user's response ([ElicitationResponse]) for the pending
  /// elicitation. No-op (with a warning log) when there is no pending
  /// elicitation — guards against a stale submit after the form has
  /// cleared in the watched stream.
  Future<void> submit(ElicitationResponse resp) async {
    final chatId = _chatId;
    final elicitation = state.elicitation;
    if (chatId == null || elicitation == null) {
      logWarning(
          '🤖 [ElicitationCubit] submit called with no pending elicitation');
      return;
    }
    final elicitationId = elicitation['elicitationId'];
    if (elicitationId is! String) {
      logWarning(
          '🤖 [ElicitationCubit] submit: pending elicitation missing elicitationId');
      return;
    }
    await tryOperation(() async {
      await _repository.respondElicitation(chatId, elicitationId, resp);
      return state.copyWith(
        status: UiFlowStatus.success,
        lastOperation: ElicitationOperation.submit,
      );
    });
  }
}
