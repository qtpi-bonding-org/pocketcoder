// ChatMonitoringCubit: owns one chat's `monitored` flag -- whether a Live
// Activity should be (re)started for it automatically the next time a run
// starts, including via server-side push-to-start when no device has the
// app foregrounded. Mirrors SessionControlsCubit's open-pattern (watch on
// open, replace subscription on a subsequent open with a different id).
import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'package:pocketcoder_flutter/domain/live_activities/i_live_activity_ender.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/domain/chat/i_chat_list_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'chat_monitoring_state.dart';

@injectable
class ChatMonitoringCubit extends AppCubit<ChatMonitoringState> {
  ChatMonitoringCubit(this._repo) : super(const ChatMonitoringState());

  final IChatListRepository _repo;

  StreamSubscription? _watchSub;
  String? _chatId;

  @override
  Future<void> close() {
    _watchSub?.cancel();
    return super.close();
  }

  /// Starts watching [chatId]'s own `monitored` flag. Calling this again
  /// with a different chatId tears down the previous subscription first.
  void open(String chatId) {
    if (_chatId == chatId) return;
    _chatId = chatId;
    _watchSub?.cancel();
    emit(state.copyWith(
      chatId: chatId,
      status: UiFlowStatus.loading,
      lastOperation: ChatMonitoringOperation.open,
    ));

    _watchSub = _repo.watchChat(chatId).listen(
      (chat) {
        emit(state.copyWith(
          monitored: chat?.monitored ?? false,
          status: UiFlowStatus.success,
        ));
      },
      onError: (Object e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
          error: e,
          source: 'ChatMonitoringCubit',
          operation: 'watchChat',
        ));
        logError('🤖 [ChatMonitoringCubit] watch error', e);
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );
  }

  /// Flips the current `monitored` value.
  Future<void> toggle() async {
    final chatId = _chatId;
    if (chatId == null) {
      logWarning('🤖 [ChatMonitoringCubit] toggle called before open()');
      return;
    }
    final next = !state.monitored;
    await tryOperation(() async {
      await _repo.setMonitored(chatId, next);
      if (!next) await _endLiveActivity(chatId);
      return state.copyWith(
        monitored: next,
        status: UiFlowStatus.success,
        lastOperation: ChatMonitoringOperation.toggle,
      );
    });
  }

  Future<void> _endLiveActivity(String chatId) async {
    // pocketcoder_flutter is also used by the FOSS app, which has no
    // proprietary ActivityKit implementation.
    if (!GetIt.instance.isRegistered<ILiveActivityEnder>()) return;

    try {
      await GetIt.instance<ILiveActivityEnder>().endForChat(chatId);
    } catch (error, stackTrace) {
      unawaited(pocketCoderDiagnosticCapture.capture(
        error: error,
        stackTrace: stackTrace,
        source: 'ChatMonitoringCubit',
        operation: 'endLiveActivity',
      ));
      AppLogger.error('Live Activity end failed', error, stackTrace);
    }
  }
}
