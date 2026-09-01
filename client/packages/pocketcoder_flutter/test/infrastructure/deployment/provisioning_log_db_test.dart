import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/provisioning_log_db.dart';

void main() {
  late ProvisioningLogDb db;
  setUp(() => db = ProvisioningLogDb.forExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('stores rows and orders by microsecond timestamp', () async {
    await db.upsertEntry(
        instanceId: 'i',
        source: 'flutter',
        timestampMicros: 20,
        journalCursor: 'a',
        level: 'info',
        message: 'later');
    await db.upsertEntry(
        instanceId: 'i',
        source: 'bootscript',
        timestampMicros: 10,
        journalCursor: 'b',
        level: 'info',
        message: 'earlier');
    final rows = await db.forInstanceOrderedByTimestamp('i');
    expect(rows.map((row) => row.timestampMicros), [10, 20]);
  });

  test('upserts the same instance/source/cursor instead of duplicating',
      () async {
    await db.upsertEntry(
        instanceId: 'i',
        source: 'bootscript',
        timestampMicros: 1,
        journalCursor: 'cursor',
        level: 'info',
        message: 'old');
    await db.upsertEntry(
        instanceId: 'i',
        source: 'bootscript',
        timestampMicros: 2,
        journalCursor: 'cursor',
        level: 'warning',
        message: 'new');
    final rows = await db.forInstanceOrderedByTimestamp('i');
    expect(rows, hasLength(1));
    expect(rows.single.message, 'new');
    expect(rows.single.timestampMicros, 2);
  });
}
