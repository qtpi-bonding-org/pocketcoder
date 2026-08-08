import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_cloud_init.dart';

void main() {
  test('emits a real cloud-init bootstrap for the application stack', () {
    final bootstrap = PocketCoderCloudInit.build(
      adminEmail: 'admin@example.test',
      adminPassword: 'throwaway-password',
      rootSshKey: 'ssh-ed25519 AAAA',
    );

    expect(
        bootstrap.userData, contains('/usr/local/sbin/pocketcoder-bootstrap'));
    expect(bootstrap.userData, contains('git clone'));
    expect(bootstrap.userData, contains("compose='docker compose'"));
    expect(bootstrap.userData, contains('checkout --detach'));
    expect(bootstrap.userData, contains('release-manifest.json'));
    expect(bootstrap.userData, contains('docker load'));
    expect(bootstrap.userData, contains('up -d --no-build'));
    expect(bootstrap.userData, isNot(contains(' compose build')));
    expect(bootstrap.userData, contains('{schema:1'));
    expect(bootstrap.userData, contains('base64 -d'));
    expect(bootstrap.userData, isNot(contains('throwaway-password')));
  });

  test('pins the checkout and release bundle to the supplied commit', () {
    final bootstrap = PocketCoderCloudInit.build(
      adminEmail: 'admin@example.test',
      adminPassword: 'password',
      rootSshKey: 'ssh-ed25519 AAAA',
      sourceCommit: '0123456789abcdef',
    );
    expect(bootstrap.userData, contains("source_commit='0123456789abcdef'"));
    expect(bootstrap.userData, contains('release-\$source_commit.json'));
    expect(bootstrap.userData, contains('release_bundle_unavailable'));
    expect(bootstrap.userData, contains('up -d --no-build'));
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
