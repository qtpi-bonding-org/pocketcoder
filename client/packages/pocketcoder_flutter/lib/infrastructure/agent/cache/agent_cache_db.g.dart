// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_cache_db.dart';

// ignore_for_file: type=lint
class $ChatEventsTable extends ChatEvents
    with TableInfo<$ChatEventsTable, ChatEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
      'chat_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
      'seq', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [chatId, seq, type, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_events';
  @override
  VerificationContext validateIntegrity(Insertable<ChatEventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chat_id')) {
      context.handle(_chatIdMeta,
          chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta));
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
          _seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chatId, seq};
  @override
  ChatEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatEventRow(
      chatId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_id'])!,
      seq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
    );
  }

  @override
  $ChatEventsTable createAlias(String alias) {
    return $ChatEventsTable(attachedDatabase, alias);
  }
}

class ChatEventRow extends DataClass implements Insertable<ChatEventRow> {
  final String chatId;
  final int seq;
  final String type;
  final String json;
  const ChatEventRow(
      {required this.chatId,
      required this.seq,
      required this.type,
      required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chat_id'] = Variable<String>(chatId);
    map['seq'] = Variable<int>(seq);
    map['type'] = Variable<String>(type);
    map['json'] = Variable<String>(json);
    return map;
  }

  ChatEventsCompanion toCompanion(bool nullToAbsent) {
    return ChatEventsCompanion(
      chatId: Value(chatId),
      seq: Value(seq),
      type: Value(type),
      json: Value(json),
    );
  }

  factory ChatEventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatEventRow(
      chatId: serializer.fromJson<String>(json['chatId']),
      seq: serializer.fromJson<int>(json['seq']),
      type: serializer.fromJson<String>(json['type']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chatId': serializer.toJson<String>(chatId),
      'seq': serializer.toJson<int>(seq),
      'type': serializer.toJson<String>(type),
      'json': serializer.toJson<String>(json),
    };
  }

  ChatEventRow copyWith(
          {String? chatId, int? seq, String? type, String? json}) =>
      ChatEventRow(
        chatId: chatId ?? this.chatId,
        seq: seq ?? this.seq,
        type: type ?? this.type,
        json: json ?? this.json,
      );
  ChatEventRow copyWithCompanion(ChatEventsCompanion data) {
    return ChatEventRow(
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      seq: data.seq.present ? data.seq.value : this.seq,
      type: data.type.present ? data.type.value : this.type,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatEventRow(')
          ..write('chatId: $chatId, ')
          ..write('seq: $seq, ')
          ..write('type: $type, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chatId, seq, type, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatEventRow &&
          other.chatId == this.chatId &&
          other.seq == this.seq &&
          other.type == this.type &&
          other.json == this.json);
}

class ChatEventsCompanion extends UpdateCompanion<ChatEventRow> {
  final Value<String> chatId;
  final Value<int> seq;
  final Value<String> type;
  final Value<String> json;
  final Value<int> rowid;
  const ChatEventsCompanion({
    this.chatId = const Value.absent(),
    this.seq = const Value.absent(),
    this.type = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatEventsCompanion.insert({
    required String chatId,
    required int seq,
    required String type,
    required String json,
    this.rowid = const Value.absent(),
  })  : chatId = Value(chatId),
        seq = Value(seq),
        type = Value(type),
        json = Value(json);
  static Insertable<ChatEventRow> custom({
    Expression<String>? chatId,
    Expression<int>? seq,
    Expression<String>? type,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chatId != null) 'chat_id': chatId,
      if (seq != null) 'seq': seq,
      if (type != null) 'type': type,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatEventsCompanion copyWith(
      {Value<String>? chatId,
      Value<int>? seq,
      Value<String>? type,
      Value<String>? json,
      Value<int>? rowid}) {
    return ChatEventsCompanion(
      chatId: chatId ?? this.chatId,
      seq: seq ?? this.seq,
      type: type ?? this.type,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatEventsCompanion(')
          ..write('chatId: $chatId, ')
          ..write('seq: $seq, ')
          ..write('type: $type, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AgentCacheDb extends GeneratedDatabase {
  _$AgentCacheDb(QueryExecutor e) : super(e);
  $AgentCacheDbManager get managers => $AgentCacheDbManager(this);
  late final $ChatEventsTable chatEvents = $ChatEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [chatEvents];
}

typedef $$ChatEventsTableCreateCompanionBuilder = ChatEventsCompanion Function({
  required String chatId,
  required int seq,
  required String type,
  required String json,
  Value<int> rowid,
});
typedef $$ChatEventsTableUpdateCompanionBuilder = ChatEventsCompanion Function({
  Value<String> chatId,
  Value<int> seq,
  Value<String> type,
  Value<String> json,
  Value<int> rowid,
});

class $$ChatEventsTableFilterComposer
    extends Composer<_$AgentCacheDb, $ChatEventsTable> {
  $$ChatEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));
}

class $$ChatEventsTableOrderingComposer
    extends Composer<_$AgentCacheDb, $ChatEventsTable> {
  $$ChatEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));
}

class $$ChatEventsTableAnnotationComposer
    extends Composer<_$AgentCacheDb, $ChatEventsTable> {
  $$ChatEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$ChatEventsTableTableManager extends RootTableManager<
    _$AgentCacheDb,
    $ChatEventsTable,
    ChatEventRow,
    $$ChatEventsTableFilterComposer,
    $$ChatEventsTableOrderingComposer,
    $$ChatEventsTableAnnotationComposer,
    $$ChatEventsTableCreateCompanionBuilder,
    $$ChatEventsTableUpdateCompanionBuilder,
    (
      ChatEventRow,
      BaseReferences<_$AgentCacheDb, $ChatEventsTable, ChatEventRow>
    ),
    ChatEventRow,
    PrefetchHooks Function()> {
  $$ChatEventsTableTableManager(_$AgentCacheDb db, $ChatEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> chatId = const Value.absent(),
            Value<int> seq = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatEventsCompanion(
            chatId: chatId,
            seq: seq,
            type: type,
            json: json,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String chatId,
            required int seq,
            required String type,
            required String json,
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatEventsCompanion.insert(
            chatId: chatId,
            seq: seq,
            type: type,
            json: json,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChatEventsTableProcessedTableManager = ProcessedTableManager<
    _$AgentCacheDb,
    $ChatEventsTable,
    ChatEventRow,
    $$ChatEventsTableFilterComposer,
    $$ChatEventsTableOrderingComposer,
    $$ChatEventsTableAnnotationComposer,
    $$ChatEventsTableCreateCompanionBuilder,
    $$ChatEventsTableUpdateCompanionBuilder,
    (
      ChatEventRow,
      BaseReferences<_$AgentCacheDb, $ChatEventsTable, ChatEventRow>
    ),
    ChatEventRow,
    PrefetchHooks Function()>;

class $AgentCacheDbManager {
  final _$AgentCacheDb _db;
  $AgentCacheDbManager(this._db);
  $$ChatEventsTableTableManager get chatEvents =>
      $$ChatEventsTableTableManager(_db, _db.chatEvents);
}
