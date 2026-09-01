// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'provisioning_log_db.dart';

class $ProvisioningLogEntriesTable extends ProvisioningLogEntries
    with TableInfo<$ProvisioningLogEntriesTable, ProvisioningLogRow> {
  $ProvisioningLogEntriesTable(GeneratedDatabase db, [String? alias])
      : attachedDatabase = db,
        _alias = alias;
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => 'provisioning_log_entries';
  late final GeneratedColumn<String> instanceId = GeneratedColumn(
      'instance_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> source = GeneratedColumn(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> timestampMicros = GeneratedColumn(
      'timestamp_micros', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<String> journalCursor = GeneratedColumn(
      'journal_cursor', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> level = GeneratedColumn(
      'level', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> message = GeneratedColumn(
      'message', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [instanceId, source, timestampMicros, journalCursor, level, message];
  @override
  Set<GeneratedColumn> get $primaryKey => {instanceId, source, journalCursor};
  @override
  VerificationContext validateIntegrity(Insertable<ProvisioningLogRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    for (final entry in <String, GeneratedColumn>{
      'instance_id': instanceId,
      'source': source,
      'timestamp_micros': timestampMicros,
      'journal_cursor': journalCursor,
      'level': level,
      'message': message,
    }.entries) {
      if (data.containsKey(entry.key)) {
        context.handle(
            VerificationMeta(entry.key),
            entry.value.isAcceptableOrUnknown(
                data[entry.key]!, VerificationMeta(entry.key)));
      } else if (isInserting) {
        context.missing(VerificationMeta(entry.key));
      }
    }
    return context;
  }

  @override
  ProvisioningLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final p = tablePrefix == null ? '' : '$tablePrefix.';
    return ProvisioningLogRow(
        instanceId: attachedDatabase.typeMapping
            .read(DriftSqlType.string, data['${p}instance_id'])!,
        source: attachedDatabase.typeMapping
            .read(DriftSqlType.string, data['${p}source'])!,
        timestampMicros: attachedDatabase.typeMapping
            .read(DriftSqlType.int, data['${p}timestamp_micros'])!,
        journalCursor: attachedDatabase.typeMapping
            .read(DriftSqlType.string, data['${p}journal_cursor'])!,
        level: attachedDatabase.typeMapping
            .read(DriftSqlType.string, data['${p}level'])!,
        message: attachedDatabase.typeMapping
            .read(DriftSqlType.string, data['${p}message'])!);
  }

  @override
  $ProvisioningLogEntriesTable createAlias(String alias) =>
      $ProvisioningLogEntriesTable(attachedDatabase, alias);
}

class ProvisioningLogRow extends DataClass
    implements Insertable<ProvisioningLogRow> {
  final String instanceId, source, journalCursor, level, message;
  final int timestampMicros;
  const ProvisioningLogRow(
      {required this.instanceId,
      required this.source,
      required this.timestampMicros,
      required this.journalCursor,
      required this.level,
      required this.message});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => {
        'instance_id': Variable(instanceId),
        'source': Variable(source),
        'timestamp_micros': Variable(timestampMicros),
        'journal_cursor': Variable(journalCursor),
        'level': Variable(level),
        'message': Variable(message)
      };

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
}

class ProvisioningLogEntriesCompanion
    extends UpdateCompanion<ProvisioningLogRow> {
  final Value<String> instanceId, source, journalCursor, level, message;
  final Value<int> timestampMicros;
  const ProvisioningLogEntriesCompanion(
      {this.instanceId = const Value.absent(),
      this.source = const Value.absent(),
      this.timestampMicros = const Value.absent(),
      this.journalCursor = const Value.absent(),
      this.level = const Value.absent(),
      this.message = const Value.absent()});
  ProvisioningLogEntriesCompanion.insert(
      {required String instanceId,
      required String source,
      required int timestampMicros,
      required String journalCursor,
      required String level,
      required String message})
      : instanceId = Value(instanceId),
        source = Value(source),
        timestampMicros = Value(timestampMicros),
        journalCursor = Value(journalCursor),
        level = Value(level),
        message = Value(message);
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => {
        if (instanceId.present) 'instance_id': Variable(instanceId.value),
        if (source.present) 'source': Variable(source.value),
        if (timestampMicros.present)
          'timestamp_micros': Variable(timestampMicros.value),
        if (journalCursor.present)
          'journal_cursor': Variable(journalCursor.value),
        if (level.present) 'level': Variable(level.value),
        if (message.present) 'message': Variable(message.value)
      };
}

abstract class _$ProvisioningLogDb extends GeneratedDatabase {
  _$ProvisioningLogDb(QueryExecutor e) : super(e);
  late final $ProvisioningLogEntriesTable provisioningLogEntries =
      $ProvisioningLogEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [provisioningLogEntries];
}
