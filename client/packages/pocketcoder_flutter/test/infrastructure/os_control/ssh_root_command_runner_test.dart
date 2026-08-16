import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_credentials_provider.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_credentials.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_exception.dart';
import 'package:pocketcoder_flutter/infrastructure/os_control/ssh_root_command_runner.dart';

class _CredentialsProvider implements IRootSshCredentialsProvider {
  const _CredentialsProvider(this.credentials);

  final RootSshCredentials? credentials;

  @override
  Future<RootSshCredentials?> readRootSshCredentials({
    required String instanceId,
  }) async =>
      credentials;
}

SshRootCommandRunner _runner(RootSshCredentials? credentials) =>
    SshRootCommandRunner(
      credentialsProvider: _CredentialsProvider(credentials),
    );

void main() {
  test('refuses a privileged operation without owner credentials', () async {
    await expectLater(
      _runner(null).run(
        instanceId: 'instance',
        host: 'example.com',
        command: RootSshCommand.updatePocketCoder,
      ),
      throwsA(
        isA<RootSshException>().having(
          (error) => error.message,
          'message',
          contains('No stored root credentials'),
        ),
      ),
    );
  });

  test('refuses a privileged operation without a pinned host identity',
      () async {
    await expectLater(
      _runner(
        const RootSshCredentials(
          privateKeyPem: 'not-reached',
          hostKeyType: '',
          hostKeyFingerprint: '',
        ),
      ).run(
        instanceId: 'instance',
        host: 'example.com',
        command: RootSshCommand.updatePocketCoder,
      ),
      throwsA(
        isA<RootSshException>().having(
          (error) => error.message,
          'message',
          contains('SSH identity is missing or invalid'),
        ),
      ),
    );
  });

  test('refuses an invalid private key before connecting', () async {
    await expectLater(
      _runner(
        const RootSshCredentials(
          privateKeyPem: 'not-a-private-key',
          hostKeyType: 'ssh-ed25519',
          hostKeyFingerprint: 'SHA256:AAAAC3NzaC1lZDI1NTE5AAAAIA',
        ),
      ).run(
        instanceId: 'instance',
        host: 'example.com',
        command: RootSshCommand.updatePocketCoder,
      ),
      throwsA(
        isA<RootSshException>().having(
          (error) => error.message,
          'message',
          contains('could not be parsed'),
        ),
      ),
    );
  });

  // Regression: dartssh2's onVerifyHostKey passes fingerprint as the
  // literal UTF-8 bytes of "SHA256:<base64>" -- not a decoded digest, and
  // not MD5. A prior version of this code decoded a "MD5:aa:bb:..." string
  // into 16 raw bytes, which could never equal what dartssh2 actually
  // compares against; every root SSH command silently failed to connect
  // until this was caught live. These pin the exact contract instead of
  // relying on a live connection to notice a regression.
  group('parseFingerprint', () {
    test('returns the fingerprint string as literal UTF-8 bytes', () {
      const value = 'SHA256:nA1lraVKLCs/jFY8qc3vOUIJzb6P/xMGFrdFx0A4JR8';
      expect(
        SshRootCommandRunner.parseFingerprint(value),
        utf8.encode(value),
      );
    });

    test('rejects an MD5-formatted fingerprint', () {
      expect(
        SshRootCommandRunner.parseFingerprint(
          'MD5:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff',
        ),
        isNull,
      );
    });

    test('rejects a bare SHA256: prefix with no digest', () {
      expect(SshRootCommandRunner.parseFingerprint('SHA256:'), isNull);
    });

    test('rejects an empty string', () {
      expect(SshRootCommandRunner.parseFingerprint(''), isNull);
    });
  });
}
