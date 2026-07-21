// Server-authoritative mirror of AG-UI events for the active chat. The
// Goose-backed c1 service is the source of truth for history; this table is
// purely a client-side cache so the Flutter UI can rehydrate after process
// death and replay frames at the cursor. Rows are keyed by (chatId, seq) so
// warm-resume upserts replace stale frames and the watcher always emits in
// monotonic order.
//
// Deviation from the plan's `@DriftDatabase` codegen sketch: this package's
// pinned toolchain can't add `drift_dev` — every drift_dev release compatible
// with the pinned `drift: 2.31.0` requires `build: >=3.0.0`, which conflicts
// with `freezed: ^2.4.6` (pins `build: ^2.3.1`, used by ~200 files across the
// app) and would have forced an unrelated, risky freezed 2->3 major bump just
// to unblock one new table. Instead this hooks drift's low-level
// `QueryExecutor` (the same runtime interface `@DriftDatabase` generates code
// against) directly with hand-written SQL, so no codegen step is needed. A
// small hand-rolled per-chat notifier stands in for the generated reactive
// query invalidation that `.watch()` would otherwise provide.
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:injectable/injectable.dart';

/// One cached AG-UI frame for a chat, keyed by the server-allocated seq.
class CachedEvent {
  const CachedEvent({
    required this.chatId,
    required this.seq,
    required this.type,
    required this.json,
  });

  final String chatId;
  final int seq;
  final String type;
  final String json;
}

const _createChatEventsTable = '''
  CREATE TABLE IF NOT EXISTS chat_events (
    chat_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    type TEXT NOT NULL,
    json TEXT NOT NULL,
    PRIMARY KEY (chat_id, seq)
  )
''';

// beforeOpen intentionally does nothing: drift's DelegatedDatabase runs
// beforeOpen callbacks before it flips its own internal "is open" flag, so a
// runCustom call issued from inside beforeOpen re-enters the same
// _debugCheckIsOpen gate and throws "Tried to run an operation without first
// calling QueryExecutor.ensureOpen()". Schema creation instead runs as an
// ordinary statement immediately after ensureOpen() returns (see
// AgentCacheDb._ensureOpen), once the executor considers itself open.
class _SchemaUser implements QueryExecutorUser {
  const _SchemaUser();

  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

/// Drift-backed cache for chat events. Production resolves a single on-disk
/// instance via the default constructor; tests construct one directly with a
/// memory `NativeDatabase.memory()` executor through [AgentCacheDb.forExecutor].
@lazySingleton
class AgentCacheDb {
  /// Production constructor — opens an on-disk SQLite database at
  /// `$getApplicationDocumentsDirectory()/agent_cache.sqlite` via drift_flutter.
  AgentCacheDb() : this.forExecutor(driftDatabase(name: 'agent_cache'));

  /// Test/embedded constructor — accepts any [QueryExecutor] (typically
  /// `NativeDatabase.memory()` so each test owns a fresh empty database).
  AgentCacheDb.forExecutor(this._executor);

  final QueryExecutor _executor;
  bool _opened = false;
  final Map<String, StreamController<void>> _chatChanges = {};

  Future<void> _ensureOpen() async {
    if (_opened) return;
    await _executor.ensureOpen(const _SchemaUser());
    await _executor.runCustom(_createChatEventsTable, const []);
    _opened = true;
  }

  StreamController<void> _notifierFor(String chatId) {
    return _chatChanges.putIfAbsent(chatId, () => StreamController.broadcast());
  }

  /// Insert or replace a single event. Conflict resolution is keyed on the
  /// composite primary key (chatId, seq), so replays of the same seq from the
  /// server overwrite the prior payload rather than duplicating it.
  Future<void> upsertEvent(
    String chatId,
    int seq,
    String type,
    String json,
  ) async {
    await _ensureOpen();
    await _executor.runInsert(
      'INSERT INTO chat_events (chat_id, seq, type, json) VALUES (?, ?, ?, ?) '
      'ON CONFLICT(chat_id, seq) DO UPDATE SET type = excluded.type, json = excluded.json',
      [chatId, seq, type, json],
    );
    if (!_notifierFor(chatId).isClosed) {
      _notifierFor(chatId).add(null);
    }
  }

  Future<List<CachedEvent>> _rowsFor(String chatId) async {
    await _ensureOpen();
    final rows = await _executor.runSelect(
      'SELECT chat_id, seq, type, json FROM chat_events WHERE chat_id = ? ORDER BY seq ASC',
      [chatId],
    );
    return rows
        .map(
          (r) => CachedEvent(
            chatId: r['chat_id'] as String,
            seq: r['seq'] as int,
            type: r['type'] as String,
            json: r['json'] as String,
          ),
        )
        .toList(growable: false);
  }

  /// Reactive watcher for a single chat, ordered by server-allocated seq.
  /// Emits the current snapshot synchronously on subscription and again on
  /// every subsequent mutation (upsertEvent/clearChat) for this chatId.
  Stream<List<CachedEvent>> watchChat(String chatId) {
    late StreamController<List<CachedEvent>> controller;
    StreamSubscription<void>? sub;

    Future<void> emit() async {
      if (controller.isClosed) return;
      controller.add(await _rowsFor(chatId));
    }

    controller = StreamController<List<CachedEvent>>(
      onListen: () {
        sub = _notifierFor(chatId).stream.listen((_) => emit());
        emit();
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Highest seq observed for the chat, or null when no rows are cached yet.
  /// Callers use this as the SSE resume cursor (`?cursor=<n>`).
  Future<int?> maxSeq(String chatId) async {
    await _ensureOpen();
    final rows = await _executor.runSelect(
      'SELECT MAX(seq) AS max_seq FROM chat_events WHERE chat_id = ?',
      [chatId],
    );
    if (rows.isEmpty) return null;
    return rows.first['max_seq'] as int?;
  }

  /// Drop all cached frames for a single chat. Other chats are untouched so
  /// concurrent conversations keep their replayable history.
  Future<void> clearChat(String chatId) async {
    await _ensureOpen();
    await _executor.runDelete(
      'DELETE FROM chat_events WHERE chat_id = ?',
      [chatId],
    );
    if (!_notifierFor(chatId).isClosed) {
      _notifierFor(chatId).add(null);
    }
  }

  /// Releases the underlying database connection. Tests should call this in
  /// tearDown so each case's in-memory database is closed cleanly.
  Future<void> close() async {
    for (final controller in _chatChanges.values) {
      await controller.close();
    }
    await _executor.close();
  }
}
