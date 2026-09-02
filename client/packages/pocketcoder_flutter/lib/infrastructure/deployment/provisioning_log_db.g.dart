// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provisioning_log_db.dart';

// ignore_for_file: type=lint
class $ProvisioningLogEntriesTable extends ProvisioningLogEntries
    with TableInfo<$ProvisioningLogEntriesTable, ProvisioningLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProvisioningLogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _instanceIdMeta =
      const VerificationMeta('instanceId');
  @override
  late final GeneratedColumn<String> instanceId = GeneratedColumn<String>(
      'instance_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMicrosMeta =
      const VerificationMeta('timestampMicros');
  @override
  late final GeneratedColumn<int> timestampMicros = GeneratedColumn<int>(
      'timestamp_micros', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _journalCursorMeta =
      const VerificationMeta('journalCursor');
  @override
  late final GeneratedColumn<String> journalCursor = GeneratedColumn<String>(
      'journal_cursor', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
      'level', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageMeta =
      const VerificationMeta('message');
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
      'message', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [instanceId, source, timestampMicros, journalCursor, level, message];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provisioning_log_entries';
  @override
  VerificationContext validateIntegrity(Insertable<ProvisioningLogRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('instance_id')) {
      context.handle(
          _instanceIdMeta,
          instanceId.isAcceptableOrUnknown(
              data['instance_id']!, _instanceIdMeta));
    } else if (isInserting) {
      context.missing(_instanceIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('timestamp_micros')) {
      context.handle(
          _timestampMicrosMeta,
          timestampMicros.isAcceptableOrUnknown(
              data['timestamp_micros']!, _timestampMicrosMeta));
    } else if (isInserting) {
      context.missing(_timestampMicrosMeta);
    }
    if (data.containsKey('journal_cursor')) {
      context.handle(
          _journalCursorMeta,
          journalCursor.isAcceptableOrUnknown(
              data['journal_cursor']!, _journalCursorMeta));
    } else if (isInserting) {
      context.missing(_journalCursorMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('message')) {
      context.handle(_messageMeta,
          message.isAcceptableOrUnknown(data['message']!, _messageMeta));
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {instanceId, source, journalCursor};
  @override
  ProvisioningLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProvisioningLogRow(
      instanceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}instance_id'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      timestampMicros: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}timestamp_micros'])!,
      journalCursor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}journal_cursor'])!,
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}level'])!,
      message: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message'])!,
    );
  }

  @override
  $ProvisioningLogEntriesTable createAlias(String alias) {
    return $ProvisioningLogEntriesTable(attachedDatabase, alias);
  }
}

class ProvisioningLogRow extends DataClass
    implements Insertable<ProvisioningLogRow> {
  final String instanceId;
  final String source;
  final int timestampMicros;
  final String journalCursor;
  final String level;
  final String message;
  const ProvisioningLogRow(
      {required this.instanceId,
      required this.source,
      required this.timestampMicros,
      required this.journalCursor,
      required this.level,
      required this.message});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['instance_id'] = Variable<String>(instanceId);
    map['source'] = Variable<String>(source);
    map['timestamp_micros'] = Variable<int>(timestampMicros);
    map['journal_cursor'] = Variable<String>(journalCursor);
    map['level'] = Variable<String>(level);
    map['message'] = Variable<String>(message);
    return map;
  }

  ProvisioningLogEntriesCompanion toCompanion(bool nullToAbsent) {
    return ProvisioningLogEntriesCompanion(
      instanceId: Value(instanceId),
      source: Value(source),
      timestampMicros: Value(timestampMicros),
      journalCursor: Value(journalCursor),
      level: Value(level),
      message: Value(message),
    );
  }

  factory ProvisioningLogRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProvisioningLogRow(
      instanceId: serializer.fromJson<String>(json['instanceId']),
      source: serializer.fromJson<String>(json['source']),
      timestampMicros: serializer.fromJson<int>(json['timestampMicros']),
      journalCursor: serializer.fromJson<String>(json['journalCursor']),
      level: serializer.fromJson<String>(json['level']),
      message: serializer.fromJson<String>(json['message']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'instanceId': serializer.toJson<String>(instanceId),
      'source': serializer.toJson<String>(source),
      'timestampMicros': serializer.toJson<int>(timestampMicros),
      'journalCursor': serializer.toJson<String>(journalCursor),
      'level': serializer.toJson<String>(level),
      'message': serializer.toJson<String>(message),
    };
  }

  ProvisioningLogRow copyWith(
          {String? instanceId,
          String? source,
          int? timestampMicros,
          String? journalCursor,
          String? level,
          String? message}) =>
      ProvisioningLogRow(
        instanceId: instanceId ?? this.instanceId,
        source: source ?? this.source,
        timestampMicros: timestampMicros ?? this.timestampMicros,
        journalCursor: journalCursor ?? this.journalCursor,
        level: level ?? this.level,
        message: message ?? this.message,
      );
  ProvisioningLogRow copyWithCompanion(ProvisioningLogEntriesCompanion data) {
    return ProvisioningLogRow(
      instanceId:
          data.instanceId.present ? data.instanceId.value : this.instanceId,
      source: data.source.present ? data.source.value : this.source,
      timestampMicros: data.timestampMicros.present
          ? data.timestampMicros.value
          : this.timestampMicros,
      journalCursor: data.journalCursor.present
          ? data.journalCursor.value
          : this.journalCursor,
      level: data.level.present ? data.level.value : this.level,
      message: data.message.present ? data.message.value : this.message,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProvisioningLogRow(')
          ..write('instanceId: $instanceId, ')
          ..write('source: $source, ')
          ..write('timestampMicros: $timestampMicros, ')
          ..write('journalCursor: $journalCursor, ')
          ..write('level: $level, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      instanceId, source, timestampMicros, journalCursor, level, message);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProvisioningLogRow &&
          other.instanceId == this.instanceId &&
          other.source == this.source &&
          other.timestampMicros == this.timestampMicros &&
          other.journalCursor == this.journalCursor &&
          other.level == this.level &&
          other.message == this.message);
}

class ProvisioningLogEntriesCompanion
    extends UpdateCompanion<ProvisioningLogRow> {
  final Value<String> instanceId;
  final Value<String> source;
  final Value<int> timestampMicros;
  final Value<String> journalCursor;
  final Value<String> level;
  final Value<String> message;
  final Value<int> rowid;
  const ProvisioningLogEntriesCompanion({
    this.instanceId = const Value.absent(),
    this.source = const Value.absent(),
    this.timestampMicros = const Value.absent(),
    this.journalCursor = const Value.absent(),
    this.level = const Value.absent(),
    this.message = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProvisioningLogEntriesCompanion.insert({
    required String instanceId,
    required String source,
    required int timestampMicros,
    required String journalCursor,
    required String level,
    required String message,
    this.rowid = const Value.absent(),
  })  : instanceId = Value(instanceId),
        source = Value(source),
        timestampMicros = Value(timestampMicros),
        journalCursor = Value(journalCursor),
        level = Value(level),
        message = Value(message);
  static Insertable<ProvisioningLogRow> custom({
    Expression<String>? instanceId,
    Expression<String>? source,
    Expression<int>? timestampMicros,
    Expression<String>? journalCursor,
    Expression<String>? level,
    Expression<String>? message,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (instanceId != null) 'instance_id': instanceId,
      if (source != null) 'source': source,
      if (timestampMicros != null) 'timestamp_micros': timestampMicros,
      if (journalCursor != null) 'journal_cursor': journalCursor,
      if (level != null) 'level': level,
      if (message != null) 'message': message,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProvisioningLogEntriesCompanion copyWith(
      {Value<String>? instanceId,
      Value<String>? source,
      Value<int>? timestampMicros,
      Value<String>? journalCursor,
      Value<String>? level,
      Value<String>? message,
      Value<int>? rowid}) {
    return ProvisioningLogEntriesCompanion(
      instanceId: instanceId ?? this.instanceId,
      source: source ?? this.source,
      timestampMicros: timestampMicros ?? this.timestampMicros,
      journalCursor: journalCursor ?? this.journalCursor,
      level: level ?? this.level,
      message: message ?? this.message,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (instanceId.present) {
      map['instance_id'] = Variable<String>(instanceId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (timestampMicros.present) {
      map['timestamp_micros'] = Variable<int>(timestampMicros.value);
    }
    if (journalCursor.present) {
      map['journal_cursor'] = Variable<String>(journalCursor.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProvisioningLogEntriesCompanion(')
          ..write('instanceId: $instanceId, ')
          ..write('source: $source, ')
          ..write('timestampMicros: $timestampMicros, ')
          ..write('journalCursor: $journalCursor, ')
          ..write('level: $level, ')
          ..write('message: $message, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ProvisioningLogDb extends GeneratedDatabase {
  _$ProvisioningLogDb(QueryExecutor e) : super(e);
  $ProvisioningLogDbManager get managers => $ProvisioningLogDbManager(this);
  late final $ProvisioningLogEntriesTable provisioningLogEntries =
      $ProvisioningLogEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [provisioningLogEntries];
}

typedef $$ProvisioningLogEntriesTableCreateCompanionBuilder
    = ProvisioningLogEntriesCompanion Function({
  required String instanceId,
  required String source,
  required int timestampMicros,
  required String journalCursor,
  required String level,
  required String message,
  Value<int> rowid,
});
typedef $$ProvisioningLogEntriesTableUpdateCompanionBuilder
    = ProvisioningLogEntriesCompanion Function({
  Value<String> instanceId,
  Value<String> source,
  Value<int> timestampMicros,
  Value<String> journalCursor,
  Value<String> level,
  Value<String> message,
  Value<int> rowid,
});

class $$ProvisioningLogEntriesTableFilterComposer
    extends Composer<_$ProvisioningLogDb, $ProvisioningLogEntriesTable> {
  $$ProvisioningLogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get instanceId => $composableBuilder(
      column: $table.instanceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timestampMicros => $composableBuilder(
      column: $table.timestampMicros,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get journalCursor => $composableBuilder(
      column: $table.journalCursor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnFilters(column));
}

class $$ProvisioningLogEntriesTableOrderingComposer
    extends Composer<_$ProvisioningLogDb, $ProvisioningLogEntriesTable> {
  $$ProvisioningLogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get instanceId => $composableBuilder(
      column: $table.instanceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timestampMicros => $composableBuilder(
      column: $table.timestampMicros,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get journalCursor => $composableBuilder(
      column: $table.journalCursor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnOrderings(column));
}

class $$ProvisioningLogEntriesTableAnnotationComposer
    extends Composer<_$ProvisioningLogDb, $ProvisioningLogEntriesTable> {
  $$ProvisioningLogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get instanceId => $composableBuilder(
      column: $table.instanceId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get timestampMicros => $composableBuilder(
      column: $table.timestampMicros, builder: (column) => column);

  GeneratedColumn<String> get journalCursor => $composableBuilder(
      column: $table.journalCursor, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);
}

class $$ProvisioningLogEntriesTableTableManager extends RootTableManager<
    _$ProvisioningLogDb,
    $ProvisioningLogEntriesTable,
    ProvisioningLogRow,
    $$ProvisioningLogEntriesTableFilterComposer,
    $$ProvisioningLogEntriesTableOrderingComposer,
    $$ProvisioningLogEntriesTableAnnotationComposer,
    $$ProvisioningLogEntriesTableCreateCompanionBuilder,
    $$ProvisioningLogEntriesTableUpdateCompanionBuilder,
    (
      ProvisioningLogRow,
      BaseReferences<_$ProvisioningLogDb, $ProvisioningLogEntriesTable,
          ProvisioningLogRow>
    ),
    ProvisioningLogRow,
    PrefetchHooks Function()> {
  $$ProvisioningLogEntriesTableTableManager(
      _$ProvisioningLogDb db, $ProvisioningLogEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProvisioningLogEntriesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$ProvisioningLogEntriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProvisioningLogEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> instanceId = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> timestampMicros = const Value.absent(),
            Value<String> journalCursor = const Value.absent(),
            Value<String> level = const Value.absent(),
            Value<String> message = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProvisioningLogEntriesCompanion(
            instanceId: instanceId,
            source: source,
            timestampMicros: timestampMicros,
            journalCursor: journalCursor,
            level: level,
            message: message,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String instanceId,
            required String source,
            required int timestampMicros,
            required String journalCursor,
            required String level,
            required String message,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProvisioningLogEntriesCompanion.insert(
            instanceId: instanceId,
            source: source,
            timestampMicros: timestampMicros,
            journalCursor: journalCursor,
            level: level,
            message: message,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProvisioningLogEntriesTableProcessedTableManager
    = ProcessedTableManager<
        _$ProvisioningLogDb,
        $ProvisioningLogEntriesTable,
        ProvisioningLogRow,
        $$ProvisioningLogEntriesTableFilterComposer,
        $$ProvisioningLogEntriesTableOrderingComposer,
        $$ProvisioningLogEntriesTableAnnotationComposer,
        $$ProvisioningLogEntriesTableCreateCompanionBuilder,
        $$ProvisioningLogEntriesTableUpdateCompanionBuilder,
        (
          ProvisioningLogRow,
          BaseReferences<_$ProvisioningLogDb, $ProvisioningLogEntriesTable,
              ProvisioningLogRow>
        ),
        ProvisioningLogRow,
        PrefetchHooks Function()>;

class $ProvisioningLogDbManager {
  final _$ProvisioningLogDb _db;
  $ProvisioningLogDbManager(this._db);
  $$ProvisioningLogEntriesTableTableManager get provisioningLogEntries =>
      $$ProvisioningLogEntriesTableTableManager(
          _db, _db.provisioningLogEntries);
}
