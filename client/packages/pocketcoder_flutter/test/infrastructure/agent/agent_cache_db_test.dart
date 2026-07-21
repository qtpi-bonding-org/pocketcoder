// Tests for the AgentCacheDb (Drift-backed server-authoritative mirror).
// Run with `flutter test test/infrastructure/agent/agent_cache_db_test.dart`.
// These tests intentionally use NativeDatabase.memory() so each case owns a
// fresh empty database — they never touch the on-disk production file.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/cache/agent_cache_db.dart';

void main() {
  late AgentCacheDb db;

  setUp(() {
    db = AgentCacheDb.forExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('upsertEvent', () {
    test('inserts a new row keyed by (chatId, seq)', () async {
      await db.upsertEvent('chat-a', 1, 'RUN_STARTED', '{"seq":1}');
      await db.upsertEvent('chat-a', 2, 'TEXT_MESSAGE_CONTENT', '{"seq":2}');

      final rows = await db.watchChat('chat-a').first;
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.seq), [1, 2]);
      expect(rows.first.type, 'RUN_STARTED');
      expect(rows.first.json, '{"seq":1}');
    });

    test('overwrites an existing row when (chatId, seq) collides', () async {
      await db.upsertEvent('chat-a', 7, 'TEXT_MESSAGE_CONTENT', '{"v":1}');

      // Same chatId + seq, different payload → must replace, not duplicate.
      await db.upsertEvent('chat-a', 7, 'TEXT_MESSAGE_CONTENT', '{"v":2}');

      final rows = await db.watchChat('chat-a').first;
      expect(rows, hasLength(1));
      expect(rows.single.seq, 7);
      expect(rows.single.json, '{"v":2}');
    });
  });

  group('watchChat', () {
    test('emits rows ordered by seq ascending', () async {
      // Insert out of order to prove the ORDER BY clause is doing the work.
      await db.upsertEvent('chat-a', 5, 'TEXT_MESSAGE_END', '{"seq":5}');
      await db.upsertEvent('chat-a', 1, 'RUN_STARTED', '{"seq":1}');
      await db.upsertEvent('chat-a', 3, 'TEXT_MESSAGE_CONTENT', '{"seq":3}');

      final rows = await db.watchChat('chat-a').first;
      expect(rows.map((r) => r.seq), [1, 3, 5]);
    });

    test('scopes by chatId — other chats are not in the stream', () async {
      await db.upsertEvent('chat-a', 1, 'RUN_STARTED', '{"chat":"a"}');
      await db.upsertEvent('chat-b', 1, 'RUN_STARTED', '{"chat":"b"}');
      await db.upsertEvent('chat-b', 2, 'TEXT_MESSAGE_CONTENT', '{"chat":"b"}');

      final aRows = await db.watchChat('chat-a').first;
      final bRows = await db.watchChat('chat-b').first;

      expect(aRows, hasLength(1));
      expect(aRows.single.json, '{"chat":"a"}');
      expect(bRows.map((r) => r.seq), [1, 2]);
      expect(bRows.every((r) => r.json.contains('"chat":"b"')), isTrue);
    });
  });

  group('maxSeq', () {
    test('returns null when no events are cached for the chat', () async {
      expect(await db.maxSeq('empty-chat'), isNull);
    });

    test('returns the high-water seq for the chat', () async {
      await db.upsertEvent('chat-a', 1, 'RUN_STARTED', '{}');
      await db.upsertEvent('chat-a', 9, 'TEXT_MESSAGE_CONTENT', '{}');
      await db.upsertEvent('chat-a', 4, 'TEXT_MESSAGE_CONTENT', '{}');

      expect(await db.maxSeq('chat-a'), 9);
    });

    test('is per-chat — does not leak across chats', () async {
      await db.upsertEvent('chat-a', 1, 'RUN_STARTED', '{}');
      await db.upsertEvent('chat-b', 42, 'RUN_STARTED', '{}');

      expect(await db.maxSeq('chat-a'), 1);
      expect(await db.maxSeq('chat-b'), 42);
    });
  });

  group('clearChat', () {
    test('empties only the given chat, leaving other chats intact', () async {
      await db.upsertEvent('chat-a', 1, 'RUN_STARTED', '{}');
      await db.upsertEvent('chat-a', 2, 'TEXT_MESSAGE_CONTENT', '{}');
      await db.upsertEvent('chat-b', 1, 'RUN_STARTED', '{}');

      await db.clearChat('chat-a');

      final aRows = await db.watchChat('chat-a').first;
      final bRows = await db.watchChat('chat-b').first;

      expect(aRows, isEmpty);
      expect(bRows, hasLength(1));
      expect(bRows.single.chatId, 'chat-b');
      expect(await db.maxSeq('chat-a'), isNull);
      expect(await db.maxSeq('chat-b'), 1);
    });

    test('is a no-op when the chat has no rows', () async {
      await db.upsertEvent('chat-a', 1, 'RUN_STARTED', '{}');
      await db.clearChat('never-written');

      final aRows = await db.watchChat('chat-a').first;
      expect(aRows, hasLength(1));
    });
  });
}
