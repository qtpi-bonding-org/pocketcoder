import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/provisioning_log_db.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/provisioning_log_importer.dart';

void main() {
  late ProvisioningLogDb db;
  setUp(() => db = ProvisioningLogDb.forExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('imports bounded journal JSON and maps sources and priorities',
      () async {
    await importProvisioningJournal(
      db: db,
      instanceId: 'instance-1',
      output: '{"__REALTIME_TIMESTAMP":"1000001","__CURSOR":"c1",'
          '"SYSLOG_IDENTIFIER":"pocketcoder-installer",'
          '"PRIORITY":"3","MESSAGE":"redacted"}\n'
          '{"__REALTIME_TIMESTAMP":"1000002","__CURSOR":"c2",'
          '"CONTAINER_NAME":"pocketcoder-api","PRIORITY":"6",'
          '"MESSAGE":"ready"}\nnot-json\n',
    );

    final rows = await db.forInstanceOrderedByTimestamp('instance-1');
    expect(rows, hasLength(2));
    expect(rows[0].source, 'bootscript');
    expect(rows[0].level, 'error');
    expect(rows[1].source, 'docker');
    expect(rows[1].level, 'info');
  });
}
