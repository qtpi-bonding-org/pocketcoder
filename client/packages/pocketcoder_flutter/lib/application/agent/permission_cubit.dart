// PermissionCubit (plan Task 12): owns the SessionState.permission slice of
// one chat's reduced Conversation stream and acts on it through the
// AgentChatRepository. Mirrors ChatCubit's open-pattern: subscribe via
// repository.watch(chatId), tear down + replace the subscription on a
// subsequent open(). Action methods (authorize/deny) never mutate the
// permission map directly — the effect arrives back through the next
// watch() emission, the same non-mutating-action discipline as
// ChatCubit.sendPrompt.
import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';

import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'permission_state.dart';

@injectable
class PermissionCubit extends AppCubit<PermissionState> {
  PermissionCubit(this._repository) : super(const PermissionState());

  final AgentChatRepository _repository;

  StreamSubscription? _watchSub;
  String? _chatId;

  @override
  Future<void> close() {
    _watchSub?.cancel();
    return super.close();
  }

  /// Starts watching [chatId]'s reduced Conversation and surfaces its
  /// `sessionState.permission` slice in [PermissionState]. Calling this again
  /// with a different chatId tears down the previous subscription first.
  void open(String chatId) {
    _chatId = chatId;
    _watchSub?.cancel();
    emit(state.copyWith(
      chatId: chatId,
      status: UiFlowStatus.loading,
      lastOperation: PermissionOperation.open,
    ));

    _watchSub = _repository.watch(chatId).listen(
      (conversation) {
        emit(state.copyWith(
          sessionState: conversation.sessionState,
          status: UiFlowStatus.success,
        ));
      },
      onError: (Object e) {
        logError('🤖 [PermissionCubit] watch($chatId) error: $e');
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );
  }

  /// Approve the pending permission with [optionId]. No-op (with a warning
  /// log) when there is no pending permission — guards against a stale tap
  /// after the request has already cleared in the watched stream.
  Future<void> authorize(String optionId) async {
    final chatId = _chatId;
    final permission = state.permission;
    if (chatId == null || permission == null) {
      logWarning('🤖 [PermissionCubit] authorize called with no pending permission');
      return;
    }
    final requestId = permission['requestId'];
    if (requestId is! String) {
      logWarning('🤖 [PermissionCubit] authorize: pending permission missing requestId');
      return;
    }
    await tryOperation(() async {
      await _repository.respondPermission(
        chatId,
        requestId,
        optionId: optionId,
      );
      return state.copyWith(
        status: UiFlowStatus.success,
        lastOperation: PermissionOperation.authorize,
      );
    });
  }

  /// Cancel/deny the pending permission. No-op (with a warning log) when
  /// there is no pending permission.
  Future<void> deny() async {
    final chatId = _chatId;
    final permission = state.permission;
    if (chatId == null || permission == null) {
      logWarning('🤖 [PermissionCubit] deny called with no pending permission');
      return;
    }
    final requestId = permission['requestId'];
    if (requestId is! String) {
      logWarning('🤖 [PermissionCubit] deny: pending permission missing requestId');
      return;
    }
    await tryOperation(() async {
      await _repository.respondPermission(
        chatId,
        requestId,
        cancelled: true,
      );
      return state.copyWith(
        status: UiFlowStatus.success,
        lastOperation: PermissionOperation.deny,
      );
    });
  }
}