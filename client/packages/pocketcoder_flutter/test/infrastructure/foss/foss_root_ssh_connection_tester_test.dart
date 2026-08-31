import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_exception.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_connection_tester.dart';

void main() {
  test(
      'an unparseable private key throws RootSshException before any '
      'network I/O', () async {
    final tester = FossRootSshConnectionTester();

    await expectLater(
      tester.testConnection(
        host: '203.0.113.10',
        privateKeyPem: 'not a real key',
      ),
      throwsA(isA<RootSshException>()),
    );
  });

  test('an empty host throws RootSshException before any network I/O',
      () async {
    final tester = FossRootSshConnectionTester();

    await expectLater(
      tester.testConnection(host: '', privateKeyPem: 'irrelevant'),
      throwsA(isA<RootSshException>()),
    );
  });
}
