import 'package:drift/drift.dart';

part 'local_settings_database.g.dart';

/// On-device UI preferences; never synced to PocketBase. Exactly one row,
/// id always 0.
class LocalSettings extends Table {
  IntColumn get id => integer()();
  BoolColumn get hapticsEnabled =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalSettings])
class LocalSettingsDatabase extends _$LocalSettingsDatabase {
  LocalSettingsDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
