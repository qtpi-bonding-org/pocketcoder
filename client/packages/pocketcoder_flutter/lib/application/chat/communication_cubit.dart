import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';
import 'package:pocketcoder_flutter/domain/communication/i_communication_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'communication_state.dart';

@injectable
class CommunicationCubit extends Cubit<CommunicationState> {
  final ICommunicationRepository _repository;

  StreamSubscription? _coldSub;
  StreamSubscription? _hotSub;

  String? _currentChatId;

  CommunicationCubit(this._repository) : super(const CommunicationState());

  @override
  Future<void> close() {
    _coldSub?.cancel();
    _hotSub?.cancel();
    return super.close();
  }

  Future<void> initialize([String title = 'PocketCoder Main']) async {
    logInfo('💬 [CommCubit] Initializing chat session: "$title"...');
    emit(state.copyWith(
      status: UiFlowStatus.loading,
      lastOperation: ChatOperation.initialize,
    ));

    try {
      _currentChatId = await _repository.ensureChat(title);
      logInfo('💬 [CommCubit] Chat ID: $_currentChatId');

      final opencodeId = await _repository.getOpencodeId(_currentChatId!);
      logInfo('💬 [CommCubit] OpenCode ID: $opencodeId');

      emit(state.copyWith(
        chatId: _currentChatId,
        opencodeId: opencodeId,
        status: UiFlowStatus.success,
      ));
      _subscribeToColdPipe(_currentChatId!);
      _subscribeToHotPipe();
      logInfo('💬 [CommCubit] Initialization complete.');
    } catch (e) {
      logError('💬 [CommCubit] Initialization failed: $e');
      emit(state.copyWith(
        error: e,
        status: UiFlowStatus.failure,
      ));
    }
  }

  Future<void> loadChatHistory() async {
    emit(state.copyWith(
      status: UiFlowStatus.loading,
      lastOperation: ChatOperation.loadHistory,
    ));
    try {
      final chats = await _repository.fetchChatHistory();
      emit(state.copyWith(
        chats: chats,
        status: UiFlowStatus.success,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: e,
        status: UiFlowStatus.failure,
      ));
    }
  }

  void _subscribeToColdPipe(String chatId) {
    _coldSub?.cancel();
    _coldSub = _repository.watchColdPipe(chatId).listen(
      (messages) {
        emit(state.copyWith(messages: messages));
      },
      onError: (e) => emit(state.copyWith(
        error: e,
        status: UiFlowStatus.failure,
      )),
    );
  }

  Future<void> sendMessage(String unusedChatId, String content) async {
    if (_currentChatId == null) {
      logWarning(
          '💬 [CommCubit] Attempted to send message but chat not initialized.');
      emit(state.copyWith(
        error: "Chat not initialized",
        status: UiFlowStatus.failure,
        lastOperation: ChatOperation.sendMessage,
      ));
      return;
    }

    logInfo(
        '💬 [CommCubit] User: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
    emit(state.copyWith(
      hotMessage: null,
      isPocoThinking: true,
      lastOperation: ChatOperation.sendMessage,
    ));

    try {
      await _repository.sendMessage(_currentChatId!, content);
      emit(state.copyWith(status: UiFlowStatus.success));
    } catch (e) {
      logError('💬 [CommCubit] Failed to send message: $e');
      emit(state.copyWith(
        error: e,
        status: UiFlowStatus.failure,
      ));
    }
  }

  void _subscribeToHotPipe() {
    if (_currentChatId == null) return;

    logDebug(
        '💬 [CommCubit] Subscribing to HotPipe (SSE) for $_currentChatId...');
    _hotSub?.cancel();
    _hotSub = _repository.watchHotPipe(_currentChatId!).listen((event) {
      event.map(
        textDelta: _onHotTextDelta,
        toolStatus: _onHotToolStatus,
        snapshot: _onHotSnapshot,
        complete: _onHotComplete,
        error: _onHotError,
      );
    }, onError: (e) {
      logError('💬 [CommCubit] HotPipe Error: $e');
      emit(state.copyWith(error: e, status: UiFlowStatus.failure));
    });
  }

  void _onHotTextDelta(HotPipeTextDelta delta) {
    // For now, we rely on Snapshots for structural updates,
    // but deltas could be used for even lower-latency character streaming.
    logDebug('💬 [CommCubit] HotDelta: ${delta.text}');
    emit(state.copyWith(isPocoThinking: true));
  }

  void _onHotToolStatus(HotPipeToolStatus status) {
    logDebug('💬 [CommCubit] HotTool: ${status.tool} (${status.status})');
    emit(state.copyWith(isPocoThinking: true));
  }

  void _onHotSnapshot(HotPipeSnapshot snapshot) {
    final currentHot = state.hotMessage ??
        Message(
          id: snapshot.messageId,
          chat: _currentChatId ?? 'temp',
          role: MessageRole.assistant,
          parts: snapshot.parts,
          created: DateTime.now(),
        );

    emit(state.copyWith(
      hotMessage: currentHot.copyWith(
        id: snapshot.messageId,
        parts: snapshot.parts,
      ),
      isPocoThinking: true,
    ));
  }

  void _onHotComplete(HotPipeComplete complete) {
    logInfo('💬 [CommCubit] HotPipe Complete: ${complete.messageId}');

    // If we have a hot message, we clear it because the Cold Pipe (DB)
    // will now take over since the record is marked 'completed' in PB.
    emit(state.copyWith(
      hotMessage: null,
      isPocoThinking: false,
    ));
  }

  void _onHotError(HotPipeError error) {
    logError('💬 [CommCubit] HotPipe Error Event: ${error.error}');
    emit(state.copyWith(
      isPocoThinking: false,
      error: error.error['message'] ?? 'Unknown agent error',
      status: UiFlowStatus.failure,
    ));
  }
}
