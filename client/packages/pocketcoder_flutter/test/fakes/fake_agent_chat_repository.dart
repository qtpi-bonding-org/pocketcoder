import 'dart:async';

import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:acp_dart/acp_dart.dart';

class FakeAgentChatRepository implements AgentChatRepository {
  final _rawEventsController = StreamController<List<BaseEvent>>.broadcast();

  final sentPrompts = <(String, String)>[];
  final cancelledChatIds = <String>[];
  final permissionResponses = <(String, String, String?, bool)>[];

  /// Test hook: simulates a new cache emission carrying the full raw event
  /// list seen so far (mirrors AgentChatRepository.watchRawEvents'
  /// row-list semantics).
  void emitRawEvents(List<BaseEvent> events) =>
      _rawEventsController.add(events);

  @override
  Stream<List<BaseEvent>> watchRawEvents(String chatId) =>
      _rawEventsController.stream;

  @override
  Stream<Conversation> watch(String chatId) => const Stream.empty();

  @override
  Future<int> ingestOnce(String chatId, {required int cursor}) async => 0;

  @override
  Future<void> cancelStreams() async {}

  @override
  Future<int> cursorFor(String chatId) async => 0;

  @override
  Future<String> sendPrompt(String chatId, String text) async {
    sentPrompts.add((chatId, text));
    return 'run-id';
  }

  @override
  Future<void> cancel(String chatId) async => cancelledChatIds.add(chatId);

  @override
  Future<void> setMode(String chatId, String modeId) async {}

  @override
  Future<void> setConfigOption(
      String chatId, SetSessionConfigOptionRequest req) async {}

  @override
  Future<void> respondPermission(
    String chatId,
    String requestId, {
    String? optionId,
    bool cancelled = false,
  }) async {
    permissionResponses.add((chatId, requestId, optionId, cancelled));
  }

  @override
  Future<void> respondElicitation(
    String chatId,
    String elicitationId,
    ElicitationResponse resp,
  ) async {}
}
