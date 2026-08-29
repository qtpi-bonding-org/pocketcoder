import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';

import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'permission_state.dart';

@injectable
class PermissionCubit extends AppCubit<PermissionState> {
  PermissionCubit(this._repository) : super(const PermissionState());

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
  /// `sessionState.permission` slice in [PermissionState]. Calling this again
  /// with a different chatId tears down the previous subscription first.
  void open(String chatId) {
    _generation++;
    final myGeneration = _generation;
    _chatId = chatId;
    _watchSub?.cancel();
    emit(state.copyWith(
      chatId: chatId,
      status: UiFlowStatus.loading,
      lastOperation: PermissionOperation.open,
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
          source: 'PermissionCubit',
          operation: 'watchStream',
        ));
        logError('🤖 [PermissionCubit] watch error', e);
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );
  }

  /// Approve the pending permission with [optionId]. No-op (with a warning
  /// log) when there is no pending permission — guards against a stale tap
  /// after the request has already cleared in the watched stream.
  Future<void> authorize(String optionId, {String? requestId}) async {
    final chatId = _chatId;
    final permission = state.permission;
    if (chatId == null || permission == null) {
      logWarning(
          '🤖 [PermissionCubit] authorize called with no pending permission');
      return;
    }
    final pendingRequestId = permission['requestId'];
    if (pendingRequestId is! String) {
      logWarning(
          '🤖 [PermissionCubit] authorize: pending permission missing requestId');
      return;
    }
    if (requestId != null && requestId != pendingRequestId) {
      logWarning(
          '🤖 [PermissionCubit] authorize requestId does not match pending permission');
      return;
    }
    await tryOperation(() async {
      await _repository.respondPermission(
        chatId,
        requestId ?? pendingRequestId,
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
  Future<void> deny({String? requestId}) async {
    final chatId = _chatId;
    final permission = state.permission;
    if (chatId == null || permission == null) {
      logWarning('🤖 [PermissionCubit] deny called with no pending permission');
      return;
    }
    final pendingRequestId = permission['requestId'];
    if (pendingRequestId is! String) {
      logWarning(
          '🤖 [PermissionCubit] deny: pending permission missing requestId');
      return;
    }
    if (requestId != null && requestId != pendingRequestId) {
      logWarning(
          '🤖 [PermissionCubit] deny requestId does not match pending permission');
      return;
    }
    await tryOperation(() async {
      await _repository.respondPermission(
        chatId,
        requestId ?? pendingRequestId,
        cancelled: true,
      );
      return state.copyWith(
        status: UiFlowStatus.success,
        lastOperation: PermissionOperation.deny,
      );
    });
  }
}
