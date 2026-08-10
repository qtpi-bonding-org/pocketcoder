import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_cloud_init.dart';

final _stageZeroScript = File(
  'assets/deployment/standard_linux_stage_zero.sh',
).readAsStringSync();

String _decodedWriteFile(String userData, String path) {
  final lines = userData.split('\n');
  final start = lines.indexOf('  - path: $path');
  final content = lines
      .skip(start + 1)
      .firstWhere((line) => line.startsWith('    content: '))
      .substring('    content: '.length);
  return utf8.decode(base64Decode(content));
}

void main() {
  test('emits a real cloud-init bootstrap for the application stack', () {
    final bootstrap = PocketCoderCloudInit.build(
      stageZeroScript: _stageZeroScript,
      adminEmail: 'admin@example.test',
      adminPassword: 'throwaway-password',
      rootSshKey: 'ssh-ed25519 AAAA',
    );

    expect(
      bootstrap.userData,
      contains('/usr/local/sbin/pocketcoder-bootstrap'),
    );
    expect(bootstrap.userData, isNot(contains('git clone')));
    final shell = _decodedWriteFile(
      bootstrap.userData,
      '/usr/local/sbin/pocketcoder-bootstrap',
    );
    expect(shell, contains('/opt/pocketcoder/releases/'));
    expect(shell, contains('.deployment.url'));
    expect(shell, contains('release-manifest.json'));
    expect(shell, contains('activate-release.sh'));
    expect(
      _decodedWriteFile(
        bootstrap.userData,
        '/var/lib/pocketcoder/config/runtime.env',
      ),
      contains('POCKETCODER_SELECTED_HARNESSES=goose'),
    );
    expect(shell, isNot(contains('docker compose up')));
    expect(shell, isNot(contains('GOOSE_SERVER__SECRET_KEY=')));
    expect(shell, contains('{schema:1'));
    expect(bootstrap.userData, isNot(contains('throwaway-password')));
  });

  test('pins the deployment snapshot and artifacts to the supplied commit', () {
    final bootstrap = PocketCoderCloudInit.build(
      stageZeroScript: _stageZeroScript,
      adminEmail: 'admin@example.test',
      adminPassword: 'password',
      rootSshKey: 'ssh-ed25519 AAAA',
      sourceCommit: '0123456789abcdef0123456789abcdef01234567',
    );

    final config = jsonDecode(_decodedWriteFile(
      bootstrap.userData,
      '/var/lib/pocketcoder/config/bootstrap.json',
    )) as Map<String, dynamic>;
    expect(
      config['requestedCommit'],
      '0123456789abcdef0123456789abcdef01234567',
    );
    expect(config['selectedHarnesses'], ['goose']);
  });

  test('serializes selected harnesses in canonical catalog order', () {
    final bootstrap = PocketCoderCloudInit.build(
      stageZeroScript: _stageZeroScript,
      adminEmail: 'admin@example.test',
      adminPassword: 'password',
      rootSshKey: 'ssh-ed25519 AAAA',
      selectedHarnesses: const ['codex', 'goose'],
    );

    expect(
      _decodedWriteFile(
        bootstrap.userData,
        '/var/lib/pocketcoder/config/runtime.env',
      ),
      contains('POCKETCODER_SELECTED_HARNESSES=goose,codex'),
    );
    final config = jsonDecode(_decodedWriteFile(
      bootstrap.userData,
      '/var/lib/pocketcoder/config/bootstrap.json',
    )) as Map<String, dynamic>;
    expect(config['selectedHarnesses'], ['goose', 'codex']);
  });

  test('rejects invalid selected harness sets before provisioning', () {
    expect(
      () => PocketCoderCloudInit.build(
        stageZeroScript: _stageZeroScript,
        adminEmail: 'admin@example.test',
        adminPassword: 'password',
        rootSshKey: 'ssh-ed25519 AAAA',
        selectedHarnesses: const [],
      ),
      throwsFormatException,
    );
    expect(
      () => PocketCoderCloudInit.build(
        stageZeroScript: _stageZeroScript,
        adminEmail: 'admin@example.test',
        adminPassword: 'password',
        rootSshKey: 'ssh-ed25519 AAAA',
        selectedHarnesses: const ['unknown'],
      ),
      throwsFormatException,
    );
  });

  test('rejects newline injection in bootstrap values', () {
    expect(
      () => PocketCoderCloudInit.build(
        stageZeroScript: _stageZeroScript,
        adminEmail: 'admin@example.test\nINJECTED=true',
        adminPassword: 'password',
        rootSshKey: 'ssh-ed25519 AAAA',
      ),
      throwsFormatException,
    );
  });

  test('emits syntactically valid POSIX shell', () {
    final bootstrap = PocketCoderCloudInit.build(
      stageZeroScript: _stageZeroScript,
      adminEmail: 'admin@example.test',
      adminPassword: 'password',
      rootSshKey: 'ssh-ed25519 AAAA',
    );
    final temp = Directory.systemTemp.createTempSync('pocketcoder-cloud-init-');
    try {
      final script = File('${temp.path}/bootstrap.sh')
        ..writeAsStringSync(_decodedWriteFile(
          bootstrap.userData,
          '/usr/local/sbin/pocketcoder-bootstrap',
        ));
      final result = Process.runSync('/bin/sh', ['-n', script.path]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      temp.deleteSync(recursive: true);
    }
  });
}
