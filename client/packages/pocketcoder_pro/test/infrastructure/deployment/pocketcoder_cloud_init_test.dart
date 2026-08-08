import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_cloud_init.dart';

void main() {
  test('emits a real cloud-init bootstrap for the application stack', () {
    final bootstrap = PocketCoderCloudInit.build(
      adminEmail: 'admin@example.test',
      adminPassword: 'throwaway-password',
      rootSshKey: 'ssh-ed25519 AAAA',
    );

    expect(bootstrap.userData, contains('/usr/local/sbin/pocketcoder-bootstrap'));
    expect(bootstrap.userData, contains('git clone'));
    expect(bootstrap.userData, contains('docker compose up -d'));
    expect(bootstrap.userData, contains('base64 -d'));
    expect(bootstrap.userData, isNot(contains('throwaway-password')));
  });

  test('rejects newline injection in bootstrap values', () {
    expect(
      () => PocketCoderCloudInit.build(
        adminEmail: 'admin@example.test\nINJECTED=true',
        adminPassword: 'password',
        rootSshKey: 'ssh-ed25519 AAAA',
      ),
      throwsFormatException,
    );
  });
}
