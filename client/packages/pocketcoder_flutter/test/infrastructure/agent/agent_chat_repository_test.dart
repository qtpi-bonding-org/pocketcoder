// Tests for AgentChatRepository (plan Task 11): a fake AgentStreamClient
// (subclassed to override connect(), so no real HTTP/PocketBase involved)
// feeding a real in-memory AgentCacheDb, asserting the replace-marker /
// warm-upsert / cursor contract.
import 'dart:async';
import 'dart:convert';

import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_actions_api.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_stream_client.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/cache/agent_cache_db.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';

/// Serves a fixed, canned list of frames from [connect] regardless of the
/// chatId/cursor passed in, then completes — no real HTTP/SSE involved.
class _FakeStreamClient extends AgentStreamClient {
  _FakeStreamClient(this.frames)
      : super(
            pocketBase: PocketBase('http://unused.local'),
            httpClient: http.Client());

  final List<StreamFrame> frames;
  int callCount = 0;
  int? lastCursor;

  @override
  Stream<StreamFrame> connect(String chatId, {required int cursor}) {
    callCount++;
    lastCursor = cursor;
    return Stream.fromIterable(frames);
  }
}

StreamFrame _frame(int seq, BaseEvent event, {String? rawJsonOverride}) {
  final rawJson = rawJsonOverride ?? jsonEncode({'type': event.type});
  return (seq: seq, rawJson: rawJson, event: event);
}

AgentActionsApi _unusedActionsApi() =>
    AgentActionsApi(PocketCoderApiClient(dio: Dio()));

void main() {
  late AgentCacheDb cache;

  setUp(() {
    cache = AgentCacheDb.forExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await cache.close();
  });

  group('ingestOnce', () {
    test('warm frames upsert into the cache', () async {
      final runStarted = RunStartedEvent(threadId: 't', runId: 'r');
      final fake = _FakeStreamClient([
        _frame(1, runStarted,
            rawJsonOverride:
                '{"type":"RUN_STARTED","threadId":"t","runId":"r"}'),
        _frame(2, RunFinishedEvent(threadId: 't', runId: 'r'),
            rawJsonOverride:
                '{"type":"RUN_FINISHED","threadId":"t","runId":"r"}'),
      ]);
      final repo = AgentChatRepository(fake, cache, _unusedActionsApi());

      await repo.ingestOnce('chat-1', cursor: 0);

      expect(await cache.maxSeq('chat-1'), 2);
      final rows = await cache.watchChat('chat-1').first;
      expect(rows.map((r) => r.seq), [1, 2]);
    });

    test('a replace-marker frame clears the chat before later frames upsert',
        () async {
      // Pre-seed a stale row that should be wiped by the marker.
      await cache.upsertEvent('chat-1', 99, 'RUN_STARTED', '{"stale":true}');

      final marker =
          CustomEvent(name: 'pocketcoder:sync', value: {'mode': 'replace'});
      final fake = _FakeStreamClient([
        _frame(1, marker,
            rawJsonOverride: jsonEncode({
              'type': 'CUSTOM',
              'name': 'pocketcoder:sync',
              'value': {'mode': 'replace'}
            })),
        _frame(2, RunStartedEvent(threadId: 't', runId: 'r'),
            rawJsonOverride:
                '{"type":"RUN_STARTED","threadId":"t","runId":"r"}'),
      ]);
      final repo = AgentChatRepository(fake, cache, _unusedActionsApi());

      await repo.ingestOnce('chat-1', cursor: 0);

      final rows = await cache.watchChat('chat-1').first;
      // The stale seq-99 row is gone, and the marker frame itself was not
      // persisted as a row — only the RUN_STARTED that followed it.
      expect(rows.map((r) => r.seq), [2]);
    });
  });

  group('cursorFor', () {
    test('returns 0 for a chat with no cached rows', () async {
      final repo = AgentChatRepository(
        _FakeStreamClient(const []),
        cache,
        _unusedActionsApi(),
      );
      expect(await repo.cursorFor('never-opened'), 0);
    });

    test('returns maxSeq for a chat with cached rows', () async {
      await cache.upsertEvent('chat-1', 7, 'RUN_STARTED', '{}');
      final repo = AgentChatRepository(
        _FakeStreamClient(const []),
        cache,
        _unusedActionsApi(),
      );
      expect(await repo.cursorFor('chat-1'), 7);
    });
  });

  group('watch', () {
    test('reduces cached rows into a Conversation', () async {
      await cache.upsertEvent(
          'chat-1',
          1,
          'TEXT_MESSAGE_START',
          jsonEncode({
            'type': 'TEXT_MESSAGE_START',
            'messageId': 'm1',
            'role': 'assistant'
          }));
      await cache.upsertEvent(
          'chat-1',
          2,
          'TEXT_MESSAGE_CONTENT',
          jsonEncode({
            'type': 'TEXT_MESSAGE_CONTENT',
            'messageId': 'm1',
            'delta': 'hi'
          }));
      await cache.upsertEvent('chat-1', 3, 'TEXT_MESSAGE_END',
          jsonEncode({'type': 'TEXT_MESSAGE_END', 'messageId': 'm1'}));

      final repo = AgentChatRepository(
        _FakeStreamClient(const []),
        cache,
        _unusedActionsApi(),
      );

      final conversation = await repo.watch('chat-1').first;
      expect(conversation.timeline, hasLength(1));
      expect((conversation.timeline.single as TextTimelineItem).text, 'hi');
    });
  });
}
