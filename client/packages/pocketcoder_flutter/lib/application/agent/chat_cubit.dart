import 'dart:async';

import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_stream_client.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/pocketcoder_ag_ui_transport.dart';
import 'package:pocketcoder_flutter/infrastructure/core/network_recovery_signal.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'chat_state.dart';
import 'provider_reauthentication_required.dart';

@injectable
class ChatCubit extends AppCubit<ChatState> {
  ChatCubit(this._repository, this._networkRecoverySignal)
      : super(const ChatState());

  final AgentChatRepository _repository;
  final NetworkRecoverySignal _networkRecoverySignal;
  PocketcoderAgUiTransport? _transport;
  ConversationReducer? _reducer;
  StreamSubscription<BaseEvent>? _eventSub;
  StreamSubscription<void>? _recoverySub;
  Completer<void>? _retryWake;
  int _generation = 0;
  bool _closed = false;
  String? _lastPrompt;

  @override
  Future<void> close() {
    if (_closed) return Future<void>.value();
    _closed = true;
    _generation++;
    _eventSub?.cancel();
    _recoverySub?.cancel();
    _retryWake?.complete();
    _transport?.dispose();
    unawaited(_repository.cancelStreams());
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
    _recoverySub?.cancel();
    _retryWake?.complete();
    _transport?.dispose();
    unawaited(_repository.cancelStreams());
    _reducer = ConversationReducer();
    _transport = PocketcoderAgUiTransport(_repository, chatId: chatId);
    final transport = _transport;
    if (transport == null) return;

    emit(state.copyWith(
      chatId: chatId,
      status: UiFlowStatus.loading,
      lastOperation: AgentChatOperation.open,
    ));

    _eventSub = transport.events.listen(
      (event) {
        if (myGeneration != _generation) return;
        final reducer = _reducer;
        if (reducer == null) return;
        reducer.apply(event);
        emit(state.copyWith(
          conversation: reducer.current,
          status: UiFlowStatus.success,
          error:
              event is RunErrorEvent && event.code == 'provider_auth_required'
                  ? const ProviderReauthenticationRequired()
                  : state.error,
        ));
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

    _recoverySub = _networkRecoverySignal.onRecovered.listen((_) {
      _retryWake?.complete();
    });

    unawaited(_ingestForever(chatId, myGeneration));
  }

  Future<void> _ingestForever(String chatId, int myGeneration) async {
    var delay = _reconnectDelay;
    var consecutiveFailures = 0;
    while (myGeneration == _generation) {
      try {
        final cursor = await _repository.cursorFor(chatId);
        final frameCount = await _repository.ingestOnce(chatId, cursor: cursor);
        if (frameCount > 0) {
          consecutiveFailures = 0;
          delay = _reconnectDelay;
        } else {
          consecutiveFailures++;
          delay = _nextDelay(delay);
        }
      } catch (e) {
        if (myGeneration != _generation) return;
        unawaited(pocketCoderDiagnosticCapture.capture(
          error: e,
          source: 'ChatCubit',
          operation: 'ingestStream',
        ));
        logError('🤖 [ChatCubit] ingest error, reconnecting', e);
        if (e is AgentStreamException && !e.isRetryable) {
          emit(state.copyWith(error: e, status: UiFlowStatus.failure));
          return;
        }
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
      await _waitForRetry(delay, myGeneration);
    }
  }

  Duration _nextDelay(Duration current) => Duration(
        milliseconds: (current.inMilliseconds * 2).clamp(
            _reconnectDelay.inMilliseconds, _maxReconnectDelay.inMilliseconds),
      );

  Future<void> _waitForRetry(Duration delay, int myGeneration) async {
    final wake = Completer<void>();
    _retryWake = wake;
    await Future.any<void>([
      Future<void>.delayed(delay),
      wake.future,
    ]);
    if (myGeneration == _generation && identical(_retryWake, wake)) {
      _retryWake = null;
    }
  }

  Future<void> sendPrompt(String text) async {
    final chatId = state.chatId;
    final transport = _transport;
    if (chatId == null || transport == null) {
      logWarning('🤖 [ChatCubit] sendPrompt called before open()');
      return;
    }
    // Incoming stream events are already generation-guarded against a
    // stale chat (see the events.listen callback in open()) -- this send
    // itself wasn't: if the user switches chats before it resolves, its
    // late result (success or failure) must not stomp the new chat's
    // state.
    final myGeneration = _generation;
    _lastPrompt = text;
    logDebug(
        '🤖 [ChatCubit] sendPrompt', {'chatId': chatId, 'length': text.length});
    // Optimistic local echo: the transcript's only real source of truth is
    // ConversationReducer, fed by the backend's AG-UI event stream — and
    // that stream never echoes the user's own prompt back (it's one-way
    // input to the run, not a replayed event). Without this, the user's
    // turn never renders even though the agent clearly received it. Insert
    // it directly via addLocalMessage so it appears immediately; if some
    // backend ever does echo it back under the same id, _upsert's keying
    // supersedes this entry in place instead of duplicating it.
    final messageId = const Uuid().v4();
    final reducer = _reducer;
    if (reducer != null) {
      reducer.addLocalMessage(
        id: messageId,
        role: 'user',
        text: text,
      );
      emit(state.copyWith(conversation: reducer.current));
    }
    await tryOperation(() async {
      try {
        await transport.sendMessage(text, messageId: messageId);
      } catch (error, stackTrace) {
        logError(
            '🤖 [ChatCubit] sendPrompt failed | {chatId: $chatId, '
            'error: $error}',
            error,
            stackTrace);
        if (myGeneration != _generation) return state;
        rethrow;
      }
      if (myGeneration != _generation) return state;
      return state.copyWith(
          status: UiFlowStatus.success,
          lastOperation: AgentChatOperation.sendPrompt);
    });
  }

  Future<void> retryLastPrompt() async {
    final prompt = _lastPrompt;
    if (prompt == null || prompt.isEmpty) return;
    await sendPrompt(prompt);
  }

  void markMessageAnimated(String messageId) {
    if (state.animatedMessageIds.contains(messageId)) return;
    emit(state.copyWith(
      animatedMessageIds: {...state.animatedMessageIds, messageId},
    ));
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
