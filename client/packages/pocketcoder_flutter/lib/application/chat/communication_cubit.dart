import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import '../../domain/chat/chat_message.dart';
import '../../domain/communication/i_communication_repository.dart';
import '../../infrastructure/core/logger.dart';
import 'communication_state.dart';

@injectable
class CommunicationCubit extends Cubit<CommunicationState> {
  final ICommunicationRepository _repository;

  StreamSubscription? _coldSub;
  StreamSubscription? _hotSub;

  String? _currentChatId;
  final Uuid _uuid = const Uuid();

  CommunicationCubit(this._repository) : super(const CommunicationState());

  @override
  Future<void> close() {
    _coldSub?.cancel();
    _hotSub?.cancel();
    return super.close();
  }

  Future<void> initialize([String title = 'PocketCoder Main']) async {
    logInfo('💬 [CommCubit] Initializing chat session: "$title"...');
    emit(state.copyWith(isLoading: true));
    try {
      _currentChatId = await _repository.ensureChat(title);
      logInfo('💬 [CommCubit] Chat ID: $_currentChatId');

      final opencodeId = await _repository.getOpencodeId(_currentChatId!);
      logInfo('💬 [CommCubit] OpenCode ID: $opencodeId');

      emit(state.copyWith(
        chatId: _currentChatId,
        opencodeId: opencodeId,
        isLoading: false,
      ));
      _subscribeToColdPipe(_currentChatId!);
      _subscribeToHotPipe();
      logInfo('💬 [CommCubit] Initialization complete.');
    } catch (e) {
      logError('💬 [CommCubit] Initialization failed: $e');
      emit(state.copyWith(
        error: 'Failed to initialize chat: $e',
        isLoading: false,
      ));
    }
  }

  Future<void> loadChatHistory() async {
    emit(state.copyWith(isLoading: true));
    try {
      final chats = await _repository.fetchChatHistory();
      emit(state.copyWith(chats: chats, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        error: 'Failed to load chat history: $e',
        isLoading: false,
      ));
    }
  }

  void _subscribeToColdPipe(String chatId) {
    _coldSub?.cancel();
    _coldSub = _repository.watchColdPipe(chatId).listen(
      (messages) {
        emit(state.copyWith(messages: messages));
      },
      onError: (e) => emit(state.copyWith(error: e.toString())),
    );
  }

  Future<void> sendMessage(String unusedChatId, String content) async {
    if (_currentChatId == null) {
      logWarning(
          '💬 [CommCubit] Attempted to send message but chat not initialized.');
      emit(state.copyWith(error: "Chat not initialized"));
      return;
    }

    logInfo(
        '💬 [CommCubit] User: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
    emit(state.copyWith(hotMessage: null, isPocoThinking: true));

    try {
      await _repository.sendMessage(_currentChatId!, content);
    } catch (e) {
      logError('💬 [CommCubit] Failed to send message: $e');
      emit(state.copyWith(error: "Failed to send: $e"));
    }
  }

  void _subscribeToHotPipe() {
    logDebug('💬 [CommCubit] Subscribing to HotPipe (SSE)...');
    _hotSub?.cancel();
    _hotSub = _repository.watchHotPipe().listen((event) {
      event.map(
        delta: _onHotDelta,
        system: _onHotSystem,
        finish: (_) => _onHotFinish(),
      );
    }, onError: (e) {
      logError('💬 [CommCubit] HotPipe Error: $e');
    });
  }

  void _onHotFinish() {
    logInfo('💬 [CommCubit] Stream finished.');
    if (state.hotMessage != null) {
      final finalizedMsg = state.hotMessage!.copyWith(isLive: false);
      emit(state.copyWith(
        hotMessage: null,
        isPocoThinking: false,
        messages: [...state.messages, finalizedMsg],
      ));
    } else {
      emit(state.copyWith(isPocoThinking: false));
    }
  }

  void _onHotDelta(HotPipeDelta delta) {
    final currentHot = state.hotMessage ??
        ChatMessage(
          id: _uuid.v4(),
          chat: _currentChatId ?? 'temp',
          role: MessageRole.assistant,
          parts: [],
          isLive: true,
          created: DateTime.now(),
        );

    List<MessagePart> parts = List.from(currentHot.parts ?? []);

    if (delta.content.isNotEmpty) {
      if (parts.isNotEmpty && parts.last is MessagePartText) {
        final last = parts.last as MessagePartText;
        parts[parts.length - 1] =
            last.copyWith(text: (last.text ?? '') + delta.content);
      } else {
        parts.add(MessagePart.text(text: delta.content));
      }
    }

    if (delta.tool != null) {
      parts.add(MessagePart.tool(
        tool: delta.tool!,
        callID: delta.callId ?? 'unknown',
        state: const ToolState.running(input: {}),
      ));
    }

    emit(state.copyWith(
      hotMessage: currentHot.copyWith(parts: parts),
      isPocoThinking: true,
    ));
  }

  void _onHotSystem(HotPipeSystem system) {
    emit(state.copyWith(isPocoThinking: true));
  }

  Future<void> simulateInteraction() async {
    // Implementation kept for legacy testing/demo purposes
    emit(state.copyWith(
      hotMessage: null,
      isPocoThinking: true,
      messages: [],
    ));

    final userMsg = ChatMessage(
        id: 'sim-user-1',
        chat: 'current',
        role: MessageRole.user,
        parts: [const MessagePart.text(text: "Check the server status.")],
        created: DateTime.now());

    emit(state.copyWith(messages: [userMsg]));
    await Future.delayed(const Duration(milliseconds: 500));

    final thoughts = [
      "Accessing internal proxy...",
      "Resolving host 'pocketbase'...",
      "Connection established.",
    ];

    for (final thought in thoughts) {
      _onHotDelta(HotPipeDelta(content: "$thought\n"));
      await Future.delayed(const Duration(milliseconds: 400));
    }

    await Future.delayed(const Duration(milliseconds: 200));
    _onHotDelta(const HotPipeDelta(
      content: "",
      tool: "curl",
      callId: "call-1",
    ));

    await Future.delayed(const Duration(milliseconds: 1500));
    _onHotDelta(
        const HotPipeDelta(content: "Status 200 OK. JSON payload valid.\n"));

    await Future.delayed(const Duration(milliseconds: 500));

    const finalAnswer =
        "The server is online and responding normally, Operator.";
    for (int i = 0; i < finalAnswer.length; i += 5) {
      final end = (i + 5 < finalAnswer.length) ? i + 5 : finalAnswer.length;
      _onHotDelta(HotPipeDelta(content: finalAnswer.substring(i, end)));
      await Future.delayed(const Duration(milliseconds: 30));
    }

    await Future.delayed(const Duration(milliseconds: 800));

    final assistantMsg = ChatMessage(
      id: 'sim-asst-1',
      chat: 'current',
      role: MessageRole.assistant,
      parts: [
        const MessagePart.text(
            text:
                "Accessing internal proxy...\nResolving host 'pocketbase'...\nConnection established.\n"),
        const MessagePart.tool(
          tool: "curl",
          callID: "call-1",
          state: ToolState.completed(
            input: {'url': '/api/health'},
            output: 'Status 200 OK. JSON payload valid.',
            title: 'Health Check',
          ),
        ),
        const MessagePart.text(
            text: "\nThe server is online and responding normally, Operator."),
      ],
      created: DateTime.now(),
    );

    emit(state.copyWith(
      hotMessage: null,
      isPocoThinking: false,
      messages: [userMsg, assistantMsg],
    ));
  }
}
