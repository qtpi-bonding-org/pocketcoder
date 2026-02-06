import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import '../../domain/chat/chat_message.dart';
import '../../domain/chat/i_chat_repository.dart';
import 'chat_state.dart';

@injectable
class ChatCubit extends Cubit<ChatState> {
  final IChatRepository _repository;
  StreamSubscription? _coldSub;
  StreamSubscription? _hotSub;
  String? _currentChatId;
  final Uuid _uuid = const Uuid();

  ChatCubit(this._repository) : super(const ChatState());

  @override
  Future<void> close() {
    _coldSub?.cancel();
    _hotSub?.cancel();
    return super.close();
  }

  Future<void> initialize([String title = 'PocketCoder Main']) async {
    try {
      _currentChatId = await _repository.ensureChat(title);
      _subscribeToColdPipe(_currentChatId!);
      _subscribeToHotPipe();
    } catch (e) {
      emit(state.copyWith(error: 'Failed to initialize chat: $e'));
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

  // ... (rest of subscribeToHotPipe and handlers remains same)

  // ...

  Future<void> sendMessage(String unusedChatId, String content) async {
    if (_currentChatId == null) {
      emit(state.copyWith(error: "Chat not initialized"));
      return;
    }

    // Optimistic UI? Maybe later.
    // Clear hot message on new send.
    emit(state.copyWith(hotMessage: null, isPocoThinking: true));

    try {
      await _repository.sendMessage(_currentChatId!, content);
    } catch (e) {
      emit(state.copyWith(error: "Failed to send: $e"));
    }
  }

  void _subscribeToHotPipe() {
    _hotSub?.cancel();
    _hotSub = _repository.watchHotPipe().listen((event) {
      event.map(
        delta: _onHotDelta,
        system: _onHotSystem,
        finish: (_) => _onHotFinish(),
      );
    });
  }

  void _onHotFinish() {
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
    // 1. Get or Create Hot Message
    final currentHot = state.hotMessage ??
        ChatMessage(
          id: 'hot-${_uuid.v4()}',
          chatId: 'current', // Placeholder
          role: MessageRole.assistant,
          parts: [],
          isLive: true,
          createdAt: DateTime.now(),
        );

    List<MessagePart> parts = List.from(currentHot.parts);

    // 2. Apply Delta
    // Ideally we match by callID or just append to the last part if compatible.
    // Simplifying: If content, find last TextPart or create one.

    if (delta.content.isNotEmpty) {
      if (parts.isNotEmpty && parts.last is MessagePartText) {
        final last = parts.last as MessagePartText;
        parts[parts.length - 1] =
            last.copyWith(content: last.content + delta.content);
      } else {
        parts.add(MessagePart.text(content: delta.content));
      }
    }

    // Tools logic (simplified for now)
    if (delta.tool != null) {
      // Create a specialized tool part
      parts.add(MessagePart.tool(
          tool: delta.tool!, callId: delta.callId ?? 'unknown'));
    }

    emit(state.copyWith(
      hotMessage: currentHot.copyWith(parts: parts),
      isPocoThinking: true,
    ));
  }

  void _onHotSystem(HotPipeSystem system) {
    // System events (logs) might just flash on the screen or be added as "Reasoning" parts.
    // For now, let's treat them as reasoning text only if we want to show them.
    // Or just set the "Thinking" state.
    emit(state.copyWith(isPocoThinking: true));
  }

  Future<void> simulateInteraction() async {
    // 1. Clear State
    emit(state.copyWith(
      hotMessage: null,
      isPocoThinking: true,
      messages: [],
    ));

    // 2. User Message (Immediate)
    final userMsg = ChatMessage(
      id: 'sim-user-1',
      chatId: 'current',
      role: MessageRole.user,
      parts: [const MessagePart.text(content: "Check the server status.")],
      createdAt: DateTime.now(),
    );
    emit(state.copyWith(messages: [userMsg]));

    await Future.delayed(const Duration(milliseconds: 500));

    // 3. Hot Pipe: Thinking (Streaming Reasoning)
    final thoughts = [
      "Accessing internal gateway...",
      "Resolving host 'pocketbase'...",
      "Connection established.",
    ];

    for (final thought in thoughts) {
      _onHotDelta(HotPipeDelta(content: "$thought\n"));
      await Future.delayed(const Duration(milliseconds: 400));
    }

    // 4. Hot Pipe: Tool Execution
    await Future.delayed(const Duration(milliseconds: 200));
    _onHotDelta(const HotPipeDelta(
      content: "",
      tool: "curl",
      callId: "call-1",
    ));
    // Simulate tool running (show input)
    // Note: Our _onHotDelta logic for tools was simple ADD.
    // Ideally we update the tool with input.
    // For this sim, let's just assume the UI renders the tool block.

    await Future.delayed(const Duration(milliseconds: 1500));

    // 5. Hot Pipe: Result parsing & Final Answer
    _onHotDelta(
        const HotPipeDelta(content: "Status 200 OK. JSON payload valid.\n"));

    await Future.delayed(const Duration(milliseconds: 500));

    // Stream the final answer too, so it appears in the log before "crystallizing"
    const finalAnswer =
        "The server is online and responding normally, Operator.";
    for (int i = 0; i < finalAnswer.length; i += 5) {
      // Stream in chunks
      final end = (i + 5 < finalAnswer.length) ? i + 5 : finalAnswer.length;
      _onHotDelta(HotPipeDelta(content: finalAnswer.substring(i, end)));
      await Future.delayed(const Duration(milliseconds: 30));
    }

    await Future.delayed(const Duration(milliseconds: 800));

    // 6. Cold Pipe: Final Answer arrives (Buffer Flush)
    // MUST MATCH EXACTLY what was streamed found above.
    final assistantMsg = ChatMessage(
      id: 'sim-asst-1',
      chatId: 'current',
      role: MessageRole.assistant,
      parts: [
        // Thought 1
        const MessagePart.text(
            content:
                "Accessing internal gateway...\nResolving host 'pocketbase'...\nConnection established.\n"),
        // Tool
        const MessagePart.tool(
            tool: "curl",
            callId: "call-1",
            input: "GET /api/health"), // Typo fixed in next step if generic
        // Thought 2 (Result) + Final Answer
        // In reality, OpenCode might split these or keep them together.
        // Let's group them to match the stream.
        const MessagePart.text(
            content:
                "Status 200 OK. JSON payload valid.\nThe server is online and responding normally, Operator."),
      ],
      createdAt: DateTime.now(),
    );

    emit(state.copyWith(
      hotMessage: null, // Clear hot buffer
      isPocoThinking: false,
      messages: [userMsg, assistantMsg], // Append to history
    ));
  }
}
