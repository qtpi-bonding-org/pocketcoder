import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:injectable/injectable.dart';

part 'provisioning_log_db.g.dart';

@DataClassName('ProvisioningLogRow')
class ProvisioningLogEntries extends Table {
  TextColumn get instanceId => text()();
  TextColumn get source => text()();
  // journald __REALTIME_TIMESTAMP, in microseconds since the epoch.
  IntColumn get timestampMicros => integer()();
  TextColumn get journalCursor => text()();
  TextColumn get level => text()();
  TextColumn get message => text()();

  @override
  Set<Column> get primaryKey => {instanceId, source, journalCursor};
}

@lazySingleton
@DriftDatabase(tables: [ProvisioningLogEntries])
class ProvisioningLogDb extends _$ProvisioningLogDb {
  ProvisioningLogDb() : super(driftDatabase(name: 'provisioning_log'));
  ProvisioningLogDb.forExecutor(super.executor);

  @override
  int get schemaVersion => 1;

  Future<void> upsertEntry({
    required String instanceId,
    required String source,
    required int timestampMicros,
    required String journalCursor,
    required String level,
    required String message,
  }) =>
      into(provisioningLogEntries).insertOnConflictUpdate(
        ProvisioningLogEntriesCompanion.insert(
          instanceId: instanceId,
          source: source,
          timestampMicros: timestampMicros,
          journalCursor: journalCursor,
          level: level,
          message: message,
        ),
      );

  Future<List<ProvisioningLogRow>> forInstanceOrderedByTimestamp(
    String instanceId,
  ) =>
      (select(provisioningLogEntries)
            ..where((t) => t.instanceId.equals(instanceId))
            ..orderBy([(t) => OrderingTerm.asc(t.timestampMicros)]))
          .get();
}
